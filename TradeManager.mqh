//+------------------------------------------------------------------+
//| TradeManager.mqh - Gestione ordini aperti                       |
//+------------------------------------------------------------------+
#ifndef __TRADE_MANAGER_MQH__
#define __TRADE_MANAGER_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/RiskManager.mqh>
#include <Scalpermt5/Logger.mqh>
#include <Scalpermt5/Utils.mqh>
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

// === Mappa ticket → ultimo SL applicato (cache per il trailing) ===
double LastTrailingSL[10000];

// === Gestione ordini aperti: Break-even e trailing ===
void ManageOpenTrades()
{
   CTrade trade;

   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (!PositionGetTicket(i)) continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if (symbol != _Symbol || magic != (ulong)MagicNumber) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double atr = iATR(_Symbol, PERIOD_M15, TrailingATRPeriod);
      if (atr <= 0.0 || tp <= 0.0) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double marketPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                       : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double maxDistance = MathAbs(tp - openPrice);
      double currentGain = (type == POSITION_TYPE_BUY) ? marketPrice - openPrice : openPrice - marketPrice;
      double gainPct = (currentGain / maxDistance) * 100.0;
      double trailingDistance = atr * TrailingATRMultiplier;
      double throttleDistance = atr * TrailingThrottleFactor;

      // === BREAK-EVEN ===
      if (EnableBreakEven && gainPct >= BreakEvenPct)
      {
         double newSL = NormalizeDouble(openPrice, _Digits);
         if ((type == POSITION_TYPE_BUY && sl < newSL) || (type == POSITION_TYPE_SELL && (sl > newSL || sl == 0.0)))
         {
            if (trade.PositionModify(_Symbol, newSL, tp))
            {
               LogInfo("🔁 Break-even → SL spostato a " + DoubleToString(newSL, _Digits));
               if (i < ArraySize(LastTrailingSL))
                  LastTrailingSL[i] = newSL;
            }
            else
            {
               LogError("❌ Errore break-even: " + trade.ResultRetcodeDescription());
            }
         }
      }

      // === TRAILING STOP ===
      if (EnableTrailing && gainPct >= TrailingActivationPct)
      {
         double desiredSL = NormalizeDouble(
            (type == POSITION_TYPE_BUY ? marketPrice - trailingDistance : marketPrice + trailingDistance),
            _Digits);
         double lastSL = (i < ArraySize(LastTrailingSL)) ? LastTrailingSL[i] : 0.0;

         if (lastSL != 0.0 && MathAbs(desiredSL - lastSL) < throttleDistance)
            continue;

         bool shouldModify =
            (type == POSITION_TYPE_BUY && desiredSL > sl + _Point) ||
            (type == POSITION_TYPE_SELL && desiredSL < sl - _Point);

         if (shouldModify && NormalizeDouble(sl, _Digits) != NormalizeDouble(desiredSL, _Digits))
         {
            if (trade.PositionModify(_Symbol, desiredSL, tp))
            {
               LogDebug((type == POSITION_TYPE_BUY ? "📈" : "📉") + " Trailing SL → aggiornato a " + DoubleToString(desiredSL, _Digits));
               if (i < ArraySize(LastTrailingSL))
                  LastTrailingSL[i] = desiredSL;
            }
            else
            {
               LogError("❌ Errore trailing: " + trade.ResultRetcodeDescription());
            }
         }
      }
   }
}

// === Verifica se il prezzo è già in una zona attiva (SL-TP di un ordine aperto) ===
bool IsInActiveTradeZone(double newSL, double newTP)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (!PositionGetTicket(i)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((ulong)PositionGetInteger(POSITION_MAGIC) != (ulong)MagicNumber) continue;

      double existingSL = PositionGetDouble(POSITION_SL);
      double existingTP = PositionGetDouble(POSITION_TP);
      if (existingSL <= 0 || existingTP <= 0) continue;

      double minZone = MathMin(existingSL, existingTP);
      double maxZone = MathMax(existingSL, existingTP);
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if (price >= minZone && price <= maxZone)
      {
         LogInfo("🚫 Prezzo in zona attiva esistente. Nuovo ordine bloccato.");
         return true;
      }

      if ((newSL >= minZone && newSL <= maxZone) || (newTP >= minZone && newTP <= maxZone))
      {
         LogInfo("🚫 Nuovo SL/TP in conflitto con zona attiva esistente. Ordine bloccato.");
         return true;
      }
   }
   return false;
}

// === Apertura nuovo ordine ===
bool OpenTrade(bool isBuy, double sl, double tp)
{
   CTrade trade;

   if (!CanOpenNewTrade())
   {
      LogInfo("🚫 MaxOpenTrades raggiunto. Nessun nuovo ordine verrà aperto.");
      return false;
   }

   if (EnableActiveZoneBlock && IsInActiveTradeZone(sl, tp))
   {
      LogInfo("🚫 Blocco attivato: ordine in zona SL–TP già attiva.");
      return false;
   }

   double lot = CalculateLotSize(sl, isBuy, RiskPercent);
   if (lot <= 0.0)
   {
      LogError("❌ Lotto non valido. Operazione annullata.");
      return false;
   }

   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLevelPips = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   if ((isBuy && ((price - sl) < stopLevelPips || (tp - price) < stopLevelPips)) ||
       (!isBuy && ((sl - price) < stopLevelPips || (price - tp) < stopLevelPips)))
   {
      LogError("❌ SL o TP troppo vicini al prezzo. SL: " + DoubleToString(sl, _Digits) +
               ", TP: " + DoubleToString(tp, _Digits) + ", Prezzo: " + DoubleToString(price, _Digits));
      return false;
   }

   bool result = isBuy ?
      trade.Buy(lot, _Symbol, price, sl, tp, "Breakout BUY") :
      trade.Sell(lot, _Symbol, price, sl, tp, "Breakout SELL");

   if (!result)
   {
      int err = GetLastError();
      LogError("❌ Errore apertura ordine (codice " + IntegerToString(err) + "): " + trade.ResultRetcodeDescription());
      return false;
   }

   LogInfo("✅ Ordine aperto correttamente. Ticket: " + IntegerToString(trade.ResultOrder()));
   return true;
}

#endif