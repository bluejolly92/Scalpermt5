//+------------------------------------------------------------------+
//|                                                          ScalperMt5.mq5 |
//|                       Expert Advisor Monolitico MQL5               |
//+------------------------------------------------------------------+
#property copyright "Andrea Pitzianti"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Indicators/Trend.mqh>
#include <Trade/PositionInfo.mqh>

CTrade trade;
CPositionInfo position;

// === Input configurabili ===
input int    MagicNumber      = 123456;
input bool   EnableVerboseLog = true;
input double RiskPercent      = 1.0;
input double SLMultiplier     = 1.5;
input double TPMultiplier     = 2.0;
input int    ATRPeriod        = 14;
input int    MaxOpenTrades    = 1;
input bool   EnableTrailingStop       = true;     // Attiva/disattiva trailing
input double TrailingStartPercent     = 50.0;     // Percentuale di TP raggiunta per attivazione
input double TrailingATRMultiplier    = 1.0;      // Moltiplicatore ATR per distanza SL
input double TrailingThrottlePips     = 5.0;      // Distanza minima in pips per aggiornare lo SL
input bool   EnableBreakEven         = true;      // Attiva/disattiva break-even
input double BreakEvenStartPercent  = 40.0;       // Percentuale TP per attivare break-even
input double BreakEvenOffsetPips    = 1.0;        // Offset sopra/sotto entry per coprire spread/commissioni
input bool   EnablePartialClose       = true;
input double PartialClosePercentTP    = 60.0;   // % di TP a cui chiudere parziale
input double PartialCloseVolumePerc   = 50.0;   // % di volume da chiudere
input bool   EnableLockProtection     = false;
input double LockTriggerPercentTP     = 80.0;
input bool   EnableStepTP          = false;   // Attiva TP a step
input double StepTP_ATR_Multiplier= 1.0;      // Quanti ATR aggiungere ad ogni step
input double StepSL_ATR_Multiplier= 0.5;      // Distanza SL in step mode
input bool EnableTimeFilter = true;
input int  StartHour        = 9;     // ora inizio operatività (server time)
input int  EndHour          = 17;    // ora fine operatività
input bool   EnableVolatilityFilter = true;
input double MinATRThreshold        = 0.0004;   // soglia minima per operare
input bool   EnableTrendFilter      = true;
input int    TrendMAPeriod          = 50;
input ENUM_TIMEFRAMES TrendMATF     = PERIOD_CURRENT; // oppure PERIOD_H1, ecc.
input string TrendDirection         = "BOTH"; // valori possibili: BUY_ONLY, SELL_ONLY, BOTH
input bool   EnableADXFilter        = true;
input int    ADXPeriod              = 14;
input double MinADXThreshold        = 25.0;
input ENUM_TIMEFRAMES ADXTimeframe = PERIOD_CURRENT;
// Filtro Supporti e Resistenze
input bool   EnableSRFilter       = true;
input double SRMinDistancePips    = 5.0;   // distanza minima per bloccare operazioni

// Filtro Pivot Points
input bool   EnablePivotFilter     = true;
input ENUM_TIMEFRAMES PivotTF     = PERIOD_D1;
input double PivotMinDistancePips = 5.0;


// == Variabili globali ==
int atr_handle;
bool isInitialized = false;
double lastSL = 0.0; // cache globale per throttling
bool partialCloseDone = false;
bool lockProtectionDone = false;
bool stepTPActivated = false;
int ma_handle;
int adx_handle;
// Dati per SR e Pivot
double recentHighs[10];
double recentLows[10];

double pivotP = 0.0;
double pivotR1 = 0.0;
double pivotS1 = 0.0;
double pivotR2 = 0.0;
double pivotS2 = 0.0;


//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   atr_handle = iATR(_Symbol, _Period, ATRPeriod);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("❌ Errore nella creazione dell'handle ATR");
      return INIT_FAILED;
   }
   
   if(EnableTrendFilter)
   {
      ma_handle = iMA(_Symbol, TrendMATF, TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
      if(ma_handle == INVALID_HANDLE)
      {
         Print("❌ Errore MA handle per filtro trend");
         return INIT_FAILED;
      }
   }
   
   if(EnableADXFilter)
   {
      adx_handle = iADX(_Symbol, ADXTimeframe, ADXPeriod);
      if(adx_handle == INVALID_HANDLE)
      {
         Print("❌ Errore creazione handle ADX");
         return INIT_FAILED;
      }
   }

   ArrayInitialize(recentHighs, 0.0);
   ArrayInitialize(recentLows, 0.0);
   
   Print("✅ EA inizializzato correttamente");
   isInitialized = true;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🛑 EA disattivato");
}

//+------------------------------------------------------------------+
//| Calcolo ATR                                                      |
//+------------------------------------------------------------------+
bool GetATR(double &atr_out)
{
   double buffer[];
   if(CopyBuffer(atr_handle, 0, 0, 1, buffer) <= 0)
   {
      Print("❌ Errore nel calcolo ATR: ", GetLastError());
      return false;
   }
   atr_out = buffer[0];
   return true;
}

//+------------------------------------------------------------------+
//| Calcolo lotto dinamico                                          |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_pips)
{
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk       = (RiskPercent / 100.0) * balance;
   double point_value = tick_value / tick_size;
   double lots = risk / (sl_pips * point_value);

   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathMax(min_lot, MathMin(max_lot, MathFloor(lots / lot_step) * lot_step));

   return lots;
}

void ApplyBreakEven()
{
   if(!EnableBreakEven)
      return;

   if(!PositionSelect(_Symbol))
      return;

   double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double tp        = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double profit_pips = MathAbs(price - entry);
   double target_pips = MathAbs(tp - entry);
   double profit_percent = (profit_pips / target_pips) * 100.0;

   // Verifica che il prezzo si stia muovendo verso il TP
   bool priceInFavorableDirection = false;
   if(type == POSITION_TYPE_BUY)
      priceInFavorableDirection = (price > entry);
   else
      priceInFavorableDirection = (price < entry);
   
   if(!priceInFavorableDirection)
      return;
   
   // Applica solo se la percentuale raggiunta è sufficiente
   if(profit_percent < BreakEvenStartPercent)
      return;


   double offset = BreakEvenOffsetPips * _Point;
   double newSL = (type == POSITION_TYPE_BUY) ? NormalizeDouble(entry + offset, _Digits)
                                              : NormalizeDouble(entry - offset, _Digits);

   // SL già impostato correttamente? Esci.
   if(MathAbs(currentSL - newSL) < _Point)
      return;

   // SL deve migliorare la posizione, mai peggiorarla
   if(type == POSITION_TYPE_BUY && newSL <= currentSL)
      return;
   if(type == POSITION_TYPE_SELL && newSL >= currentSL)
      return;

   if(trade.PositionModify(_Symbol, newSL, tp))
   {
      Print("🟢 Break-even attivato. SL spostato a ", DoubleToString(newSL, _Digits),
            " (offset: ", BreakEvenOffsetPips, " pips)");
   }
   else
   {
      Print("❌ Errore applicazione break-even: ", trade.ResultRetcodeDescription());
   }
}

void ApplyStepTP()
{
   if(!EnableStepTP || stepTPActivated)
      return;

   if(!PositionSelect(_Symbol))
      return;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp    = PositionGetDouble(POSITION_TP);
   double sl    = PositionGetDouble(POSITION_SL);
   double price = SymbolInfoDouble(_Symbol, (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SYMBOL_BID : SYMBOL_ASK);

   if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && price < tp) ||
      (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && price > tp))
      return;

   double atr;
   if(!GetATR(atr))
      return;

   // Calcola nuovi livelli
   double new_tp = 0, new_sl = 0;

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      new_tp = tp + (atr * StepTP_ATR_Multiplier);
      new_sl = price - (atr * StepSL_ATR_Multiplier);
   }
   else
   {
      new_tp = tp - (atr * StepTP_ATR_Multiplier);
      new_sl = price + (atr * StepSL_ATR_Multiplier);
   }

   // Normalizza
   new_tp = NormalizeDouble(new_tp, _Digits);
   new_sl = NormalizeDouble(new_sl, _Digits);

   if(trade.PositionModify(_Symbol, new_sl, new_tp))
   {
      stepTPActivated = true;
      Print("📈 TP a Step attivato! Nuovo TP: ", DoubleToString(new_tp, _Digits),
            " - Nuovo SL: ", DoubleToString(new_sl, _Digits));
   }
   else
   {
      Print("❌ Errore aggiornamento Step TP: ", trade.ResultRetcodeDescription());
   }
}

void UpdateSupportResistanceLevels()
{
   MqlRates dailyRates[];
   int copied = CopyRates(_Symbol, PERIOD_D1, 1, 10, dailyRates);

   if(copied < 10)
   {
      Print("⚠️ Non è stato possibile ottenere 10 barre giornaliere. Copiati: ", copied);
      return;
   }

   ArraySetAsSeries(dailyRates, true);

   for(int i = 0; i < 10; i++)
   {
      recentHighs[i] = dailyRates[i].high;
      recentLows[i]  = dailyRates[i].low;
   }

   if(EnableVerboseLog)
   {
      Print("📊 Livelli SR aggiornati:");
      for(int i = 0; i < 10; i++)
         Print("  High[", i, "] = ", recentHighs[i], " | Low[", i, "] = ", recentLows[i]);
   }
}

void ApplyLockProtection()
{
   if(!EnableLockProtection || lockProtectionDone)
      return;

   if(!PositionSelect(_Symbol))
      return;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp    = PositionGetDouble(POSITION_TP);
   double volume= PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double profit_pips    = MathAbs(price - entry);
   double target_pips    = MathAbs(tp - entry);
   double profit_percent = (profit_pips / target_pips) * 100.0;

   if(profit_percent < LockTriggerPercentTP)
      return;

   ENUM_ORDER_TYPE lock_order = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   double price_lock = (lock_order == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double atr;
   if(!GetATR(atr))
      return;
   
   double sl_lock = 0, tp_lock = entry;  // TP = entry della posizione originale
   
   if(lock_order == ORDER_TYPE_BUY)
      sl_lock = price_lock - atr;  // fail-safe
   else
      sl_lock = price_lock + atr;
   
   sl_lock = NormalizeDouble(sl_lock, _Digits);
   tp_lock = NormalizeDouble(tp_lock, _Digits);
   
   bool success = false;
   if(lock_order == ORDER_TYPE_BUY)
      success = trade.Buy(volume, _Symbol, price_lock, sl_lock, tp_lock, "LOCK Protection");
   else
      success = trade.Sell(volume, _Symbol, price_lock, sl_lock, tp_lock, "LOCK Protection");

   if(success)
   {
      lockProtectionDone = true;
      Print("🔒 Lock protection attivata. Ordine opposto aperto: ", (lock_order == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            " volume: ", volume, " @ ", DoubleToString(price_lock, _Digits));
   }
   else
   {
      Print("❌ Errore apertura ordine di lock: ", trade.ResultRetcodeDescription());
   }
}

void ApplyPartialClose()
{
   if(!EnablePartialClose || partialCloseDone)
      return;

   if(!PositionSelect(_Symbol))
      return;

   double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp        = PositionGetDouble(POSITION_TP);
   double current_volume = PositionGetDouble(POSITION_VOLUME);
   double min_lot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot_step  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double profit_pips = MathAbs(price - entry);
   double target_pips = MathAbs(tp - entry);
   double profit_percent = (profit_pips / target_pips) * 100.0;

   if(profit_percent < PartialClosePercentTP)
      return;

   // Calcola volume da chiudere
   double close_volume = current_volume * (PartialCloseVolumePerc / 100.0);
   close_volume = MathMax(min_lot, MathFloor(close_volume / lot_step) * lot_step);

   // Evita doppie chiusure: chiudi solo se è ancora possibile
   if(close_volume >= current_volume || close_volume < min_lot)
      return;

   ulong ticket = PositionGetInteger(POSITION_TICKET);
   if(trade.PositionClosePartial(_Symbol, close_volume))
   {
      partialCloseDone = true;  // ✅ Chiusura avvenuta: blocca future esecuzioni
      Print("🔻 Chiusura parziale eseguita: ", DoubleToString(close_volume, 2), " lotti (", 
            PartialCloseVolumePerc, "% al raggiungimento del ", PartialClosePercentTP, "% del TP)");
   }
   else
   {
      Print("❌ Errore chiusura parziale: ", trade.ResultRetcodeDescription());
   }
}

void ApplyTrailingStop()
{
   if(!EnableTrailingStop)
      return;

   if(!PositionSelect(_Symbol))
      return;

   ulong ticket     = PositionGetInteger(POSITION_TICKET);
   double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double tp        = PositionGetDouble(POSITION_TP);
   double volume    = PositionGetDouble(POSITION_VOLUME);
   double atr;

   if(currentSL == 0.0 || tp == 0.0)  // protezione: SL o TP non impostati
      return;

   if(!GetATR(atr))
      return;

   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double profit_pips = MathAbs(current_price - entry);
   double target_pips = MathAbs(tp - entry);
   double profit_percent = (profit_pips / target_pips) * 100.0;

   if(profit_percent < TrailingStartPercent)
      return;

   // Calcolo nuova SL
   double new_sl = 0;
   if(type == POSITION_TYPE_BUY)
      new_sl = current_price - (atr * TrailingATRMultiplier);
   else
      new_sl = current_price + (atr * TrailingATRMultiplier);
   
   // ❌ Evita peggioramenti: lo SL può solo migliorare (stringersi)
   bool isBetter = false;
   if(type == POSITION_TYPE_BUY)
      isBetter = (new_sl > currentSL);
   else
      isBetter = (new_sl < currentSL);
   
   if(!isBetter)
      return;
   
   // ✅ Controllo throttling in pips
   double distance = MathAbs(currentSL - new_sl);
   if(distance < (TrailingThrottlePips * _Point))
      return;
   
   // Se tutto ok, aggiorna SL
   if(trade.PositionModify(_Symbol, new_sl, tp)) {
      Print("🔁 Trailing SL aggiornato. Nuovo SL: ", DoubleToString(new_sl, _Digits),
            " (distanza cambiamento: ", DoubleToString(distance / _Point, 1), " pips)");
   } else {
      Print("❌ Errore aggiornamento SL: ", trade.ResultRetcodeDescription());
   }

}

bool IsNearSupportResistance(ENUM_ORDER_TYPE type, double price)
{
   double minDistance = SRMinDistancePips * _Point;

   if(type == ORDER_TYPE_BUY)
   {
      for(int i = 0; i < ArraySize(recentLows); i++)
      {
         if(MathAbs(price - recentLows[i]) < minDistance)
         {
            if(EnableVerboseLog)
               Print("🛑 BUY bloccato: troppo vicino al supporto ", recentLows[i]);
            return true;
         }
      }
   }
   else if(type == ORDER_TYPE_SELL)
   {
      for(int i = 0; i < ArraySize(recentHighs); i++)
      {
         if(MathAbs(price - recentHighs[i]) < minDistance)
         {
            if(EnableVerboseLog)
               Print("🛑 SELL bloccato: troppo vicino alla resistenza ", recentHighs[i]);
            return true;
         }
      }
   }

   return false;
}

void UpdatePivotLevels()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, PivotTF, 1, 1, rates) != 1)
   {
      Print("⚠️ Errore nel caricamento dati Pivot TF");
      return;
   }

   double high  = rates[0].high;
   double low   = rates[0].low;
   double close = rates[0].close;

   pivotP  = (high + low + close) / 3.0;
   pivotR1 = 2 * pivotP - low;
   pivotS1 = 2 * pivotP - high;
   pivotR2 = pivotP + (high - low);
   pivotS2 = pivotP - (high - low);

   if(EnableVerboseLog)
   {
      Print("📐 Pivot aggiornati: P=", pivotP, " R1=", pivotR1, " S1=", pivotS1, 
            " R2=", pivotR2, " S2=", pivotS2);
   }
}

bool IsNearPivotPoint(double price)
{
   double minDist = PivotMinDistancePips * _Point;

   double pivots[] = {pivotP, pivotR1, pivotR2, pivotS1, pivotS2};

   for(int i = 0; i < ArraySize(pivots); i++)
   {
      if(MathAbs(price - pivots[i]) < minDist)
      {
         if(EnableVerboseLog)
            Print("🛑 Operazione bloccata: troppo vicino al pivot ", pivots[i]);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!isInitialized)
      return;

   static datetime lastUpdate = 0;
   MqlDateTime tm_now, tm_last;

   TimeToStruct(TimeCurrent(), tm_now);
   TimeToStruct(lastUpdate, tm_last);

   if(tm_now.day != tm_last.day)
   {
      UpdateSupportResistanceLevels();
      UpdatePivotLevels();
      lastUpdate = TimeCurrent();
      if(EnableVerboseLog)
      Print("🔄 Livelli Supporto/Resistenza aggiornati per il giorno ", 
            IntegerToString(tm_now.day), "/", IntegerToString(tm_now.mon), "/", IntegerToString(tm_now.year));
   }

   
   // === Determina tipo operazione: BUY o SELL ===
   ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;
   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double open = iOpen(_Symbol, _Period, 1);
   double close = iClose(_Symbol, _Period, 1);
   if(close < open)
   {
      order_type = ORDER_TYPE_SELL;
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }

   // === Filtro orario ===
   if(EnableTimeFilter)
   {
      MqlDateTime tm;
      TimeToStruct(TimeCurrent(), tm);
      int currentHour = tm.hour;

      if(currentHour < StartHour || currentHour >= EndHour)
      {
         if(EnableVerboseLog)
            Print("🕑 Filtro orario attivo. Ora attuale: ", currentHour,
                  " - Fascia operativa: ", StartHour, "–", EndHour);
         return;
      }
   }

   // === Filtro volatilità (ATR) ===
   double atr;
   if(!GetATR(atr))
      return;

   if(EnableVolatilityFilter && atr < MinATRThreshold)
   {
      if(EnableVerboseLog)
         Print("🌫️ Filtro ATR attivo. ATR corrente: ", DoubleToString(atr, _Digits),
               " < soglia minima: ", MinATRThreshold);
      return;
   }

   // === Filtro trend MA migliorato ===
   if(EnableTrendFilter)
   {
      double ma_buffer[];
      if(CopyBuffer(ma_handle, 0, 1, 1, ma_buffer) <= 0)
      {
         Print("❌ Errore lettura MA: ", GetLastError());
         return;
      }
   
      double ma = ma_buffer[0];
      double priceBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double priceAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
      if(EnableSRFilter && IsNearSupportResistance(order_type, entry_price))
      return;

      // Blocca operazioni in controtrend
      if(order_type == ORDER_TYPE_BUY && priceBid < ma)
      {
         if(EnableVerboseLog)
            Print("🔴 BUY bloccato dal filtro MA (Prezzo BID <", DoubleToString(ma, _Digits), ")");
         return;
      }
   
      if(order_type == ORDER_TYPE_SELL && priceAsk > ma)
      {
         if(EnableVerboseLog)
            Print("🔴 SELL bloccato dal filtro MA (Prezzo ASK >", DoubleToString(ma, _Digits), ")");
         return;
      }
   }

   // === Filtro forza del trend (ADX) ===
   if(EnableADXFilter)
   {
      double adx_buffer[];
      if(CopyBuffer(adx_handle, 0, 1, 1, adx_buffer) <= 0)
      {
         Print("❌ Errore lettura ADX: ", GetLastError());
         return;
      }

      double adx = adx_buffer[0];
      if(adx < MinADXThreshold)
      {
         if(EnableVerboseLog)
            Print("⚠️ Filtro ADX attivo: trend troppo debole (", DoubleToString(adx, 2),
                  " < soglia ", MinADXThreshold, ")");
         return;
      }
   }

   // === Gestione posizione attiva ===
   ApplyBreakEven();
   ApplyPartialClose();
   ApplyTrailingStop();
   ApplyLockProtection();
   ApplyStepTP();

   if(!PositionSelect(_Symbol))
   {
      partialCloseDone = false;
      lockProtectionDone = false;
      stepTPActivated = false;
   }

   if(EnablePivotFilter && IsNearPivotPoint(entry_price))
      return;

   // === Controllo limite numero posizioni ===
   if(PositionSelect(_Symbol) || PositionsTotal() >= MaxOpenTrades)
      return;

   // === Calcolo SL e TP ===
   double sl_pips = atr * SLMultiplier;
   double tp_pips = atr * TPMultiplier;

   double sl_price = 0, tp_price = 0;

   if(order_type == ORDER_TYPE_BUY)
   {
      sl_price = entry_price - sl_pips;
      tp_price = entry_price + tp_pips;
   }
   else
   {
      sl_price = entry_price + sl_pips;
      tp_price = entry_price - tp_pips;
   }

   double lot_size = CalculateLotSize(sl_pips);
   bool result = false;

   if(order_type == ORDER_TYPE_BUY)
      result = trade.Buy(lot_size, _Symbol, entry_price, sl_price, tp_price, "Scalper BUY");
   else
      result = trade.Sell(lot_size, _Symbol, entry_price, sl_price, tp_price, "Scalper SELL");

   if(result)
   {
      Print("✅ Ordine ", (order_type == ORDER_TYPE_BUY ? "BUY" : "SELL"), " aperto");
      Print("🔹 Lotto: ", lot_size, " SL: ", sl_price, " TP: ", tp_price, " ATR: ", atr);
   }
   else
   {
      Print("❌ Errore apertura ordine: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}
