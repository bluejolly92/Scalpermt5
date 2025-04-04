//+------------------------------------------------------------------+
//| TradeManager.mqh - Gestione ordini aperti                        |
//+------------------------------------------------------------------+
#ifndef __TRADE_MANAGER_MQH__
#define __TRADE_MANAGER_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/RiskManager.mqh>
#include <Scalpermt5/Logger.mqh>
#include <Scalpermt5/Utils.mqh>
#include <Trade/Trade.mqh>
#include <Arrays/ArrayLong.mqh>
#include <Arrays/ArrayDouble.mqh>

CTrade trade;
CArrayLong   PositionTickets;
CArrayDouble LastTrailingSL;

// === Inizializza cache trailing SL ===
void InitTrailingSLCache()
{
   PositionTickets.Clear();
   LastTrailingSL.Clear();
}

// === Ottieni indice del ticket nella cache ===
int GetPositionIndex(ulong ticket)
{
   for(int idx=0; idx<PositionTickets.Total(); idx++)
      if(PositionTickets.At(idx)==ticket) return idx;
   PositionTickets.Add(ticket);
   LastTrailingSL.Add(0.0);
   return PositionTickets.Total()-1;
}

// === Gestione trailing stop e break-even ===
void ManageOpenTrades()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      string symbol = PositionGetSymbol(i);
      if(symbol == NULL || symbol == "") continue;
      if(!PositionSelect(symbol)) continue;

      if(symbol != _Symbol || PositionGetInteger(POSITION_MAGIC) != (ulong)MagicNumber) continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      int posIdx = GetPositionIndex(ticket);

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double atr = iATR(_Symbol, PERIOD_M15, TrailingATRPeriod);
      if(atr <= 0.0 || tp <= 0.0) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double marketPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double maxDistance = MathAbs(tp - openPrice);
      double currentGain = (type == POSITION_TYPE_BUY) ? marketPrice - openPrice : openPrice - marketPrice;
      double gainPct = (currentGain / maxDistance) * 100.0;
      double trailingDistance = atr * TrailingATRMultiplier;
      double throttleDistance = atr * TrailingThrottleFactor;

      // === BREAK-EVEN ===
      if(EnableBreakEven && gainPct >= BreakEvenPct)
      {
         double newSL = NormalizeDouble(openPrice, _Digits);
         if((type == POSITION_TYPE_BUY && sl < newSL) || (type == POSITION_TYPE_SELL && (sl > newSL || sl == 0.0)))
         {
            if(trade.PositionModify(_Symbol, newSL, tp))
            {
               LogInfo("🔁 Break-even → SL spostato a " + DoubleToString(newSL, _Digits));
               LastTrailingSL.Update(posIdx, newSL);
            }
            else
               LogError("❌ Errore break-even: " + trade.ResultRetcodeDescription());
         }
      }

      // === TRAILING STOP ===
      if(EnableTrailing && gainPct >= TrailingActivationPct)
      {
         double desiredSL = NormalizeDouble((type == POSITION_TYPE_BUY ? marketPrice - trailingDistance : marketPrice + trailingDistance), _Digits);
         double lastSL = LastTrailingSL.At(posIdx);

         if(lastSL != 0.0 && MathAbs(desiredSL - lastSL) < throttleDistance)
            continue;

         bool shouldModify =
            (type == POSITION_TYPE_BUY && desiredSL > sl + _Point) ||
            (type == POSITION_TYPE_SELL && desiredSL < sl - _Point);

         if(shouldModify && NormalizeDouble(sl, _Digits) != NormalizeDouble(desiredSL, _Digits))
         {
            if(trade.PositionModify(_Symbol, desiredSL, tp))
            {
               LogDebug((type == POSITION_TYPE_BUY ? "📈" : "📉") + " Trailing SL aggiornato a " + DoubleToString(desiredSL, _Digits));
               LastTrailingSL.Update(posIdx, desiredSL);
            }
            else
               LogError("❌ Errore trailing: " + trade.ResultRetcodeDescription());
         }
      }
   }
}

// === Verifica se il prezzo è già in una zona attiva (SL-TP) ===
bool IsInActiveTradeZone(double newSL, double newTP)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      string symbol = PositionGetSymbol(i);
      if(symbol == NULL || symbol == "") continue;
      if(!PositionSelect(symbol)) continue;

      if (symbol != _Symbol || PositionGetInteger(POSITION_MAGIC) != (ulong)MagicNumber) continue;

      double existingSL = PositionGetDouble(POSITION_SL);
      double existingTP = PositionGetDouble(POSITION_TP);
      if (existingSL <= 0 || existingTP <= 0) continue;

      double minZone = MathMin(existingSL, existingTP);
      double maxZone = MathMax(existingSL, existingTP);
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if ((price >= minZone && price <= maxZone) ||
          (newSL >= minZone && newSL <= maxZone) ||
          (newTP >= minZone && newTP <= maxZone))
      {
         LogInfo("🚫 Nuovo ordine bloccato: SL/TP in zona attiva [" +
                 DoubleToString(minZone, _Digits) + " - " + DoubleToString(maxZone, _Digits) + "]");
         return true;
      }
   }

   return false;
}

// === Verifica numero massimo di ordini aperti ===
bool CanOpenNewTrade()
{
   int activeTrades = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);

      if(symbol != _Symbol) continue;
      if(magic != (ulong)MagicNumber) continue;

      activeTrades++;
   }

   LogDebug("🧮 Open positions: " + IntegerToString(activeTrades) + " / Max: " + IntegerToString(MaxOpenTrades));
   return (activeTrades < MaxOpenTrades);
}


// === Apertura ordine ===
bool OpenTrade(bool isBuy, double sl, double tp)
{
   if(!CanOpenNewTrade())
   {
      LogInfo("🚫 MaxOpenTrades raggiunto.");
      return false;
   }

   if(EnableActiveZoneBlock && IsInActiveTradeZone(sl, tp))
   {
      LogInfo("🚫 Ordine bloccato (zona attiva).");
      return false;
   }

   double lot = CalculateLotSize(sl, isBuy, RiskPercent);
   lot = MathMax(LotSizeMin, MathMin(lot, LotSizeMax));
   if(lot <= 0.0)
   {
      LogError("❌ Lotto non valido.");
      return false;
   }

   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   if((isBuy && ((price - sl) < stopLevel || (tp - price) < stopLevel)) ||
      (!isBuy && ((sl - price) < stopLevel || (price - tp) < stopLevel)))
   {
      LogError("❌ SL/TP troppo vicini. StopLevel: " + DoubleToString(stopLevel, _Digits));
      return false;
   }

   if(!(isBuy ? trade.Buy(lot, _Symbol, price, sl, tp) : trade.Sell(lot, _Symbol, price, sl, tp)))
   {
      LogError("❌ Errore ordine: " + trade.ResultRetcodeDescription() + " Prezzo: " + DoubleToString(price, _Digits));
      return false;
   }

   LogInfo("✅ Ordine aperto. Ticket: " + IntegerToString(trade.ResultOrder()));
   return true;
}

#endif
