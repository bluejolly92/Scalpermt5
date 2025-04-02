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
input double RiskPercent      = 1.0;
input double SLMultiplier     = 1.5;
input double TPMultiplier     = 2.0;
input int    ATRPeriod        = 14;
input int    MaxOpenTrades    = 1;
input int    MagicNumber      = 123456;
input bool   EnableVerboseLog = true;

int atr_handle;
bool isInitialized = false;

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

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!isInitialized)
      return;

   // Verifica se esiste già una posizione aperta su questo simbolo
   if(PositionSelect(_Symbol) || PositionsTotal() >= MaxOpenTrades)
      return;

   // Calcolo ATR
   double atr;
   if(!GetATR(atr))
      return;

   double sl_pips = atr * SLMultiplier;
   double tp_pips = atr * TPMultiplier;

   double sl_price = 0, tp_price = 0;
   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // default Buy
   ENUM_ORDER_TYPE order_type = ORDER_TYPE_BUY;

   // Logica semplificata: se ultima candela è ribassista, SELL
   double open = iOpen(_Symbol, _Period, 1);
   double close = iClose(_Symbol, _Period, 1);
   if(close < open)
   {
      order_type = ORDER_TYPE_SELL;
      entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }

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
