//+------------------------------------------------------------------+
//| RiskManager.mqh - Calcolo SL/TP e Lotto Dinamico                |
//+------------------------------------------------------------------+
#ifndef __RISK_MANAGER_MQH__
#define __RISK_MANAGER_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/Logger.mqh>

// === Calcolo SL/TP dinamici ===
bool CalculateDynamicSLTP(bool isBuy, double &sl, double &tp)
{
   int atrHandle = iATR(_Symbol, PERIOD_M15, ATR_Period);
   if (atrHandle == INVALID_HANDLE)
   {
      LogError("❌ Impossibile creare handle ATR");
      return false;
   }

   double atrBuffer[];
   if (CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
   {
      LogError("❌ Errore nella lettura del buffer ATR");
      return false;
   }

   double atr = atrBuffer[0];
   if (atr <= 0.0 || atr < MinATR)
   {
      LogDebug("❌ ATR troppo basso o nullo per SL/TP: " + DoubleToString(atr, 5));
      return false;
   }

   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slOffset = atr * SL_ATR_Mult;
   double tpOffset = atr * TP_ATR_Mult;

   if (isBuy)
   {
      sl = NormalizeDouble(price - slOffset, _Digits);
      tp = NormalizeDouble(price + tpOffset, _Digits);
   }
   else
   {
      sl = NormalizeDouble(price + slOffset, _Digits);
      tp = NormalizeDouble(price - tpOffset, _Digits);
   }

   LogDebug("📐 SL/TP calcolati → SL: " + DoubleToString(sl, _Digits) + " | TP: " + DoubleToString(tp, _Digits));
   return true;
}

// === Calcolo lotto dinamico in base a RiskPercent e SL ===
double CalculateLotSize(double stopLossPrice, bool isBuy, double riskPercent)
{
   double price        = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance   = MathAbs(price - stopLossPrice);

   double minSLDistance = _Point * 10;
   if (slDistance < minSLDistance)
   {
      slDistance = minSLDistance;
      Print("[WARNING] SL troppo stretto. Usato minimo: ", DoubleToString(slDistance, _Digits));
   }

   double tickValue    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotSize      = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double riskAmount   = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100.0;

   double lot = (riskAmount / (slDistance / _Point * tickValue));

   double maxLot = 100.0;
   if (lot > maxLot)
   {
      Print("[WARNING] Lotto calcolato troppo alto (", DoubleToString(lot, 2), "), limitato a ", DoubleToString(maxLot, 2));
      lot = maxLot;
   }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / lotStep) * lotStep;
   if (lot < minLot)
   {
      Print("[WARNING] Lotto troppo basso, impostato a minimo: ", minLot);
      lot = minLot;
   }

   double marginRequiredPerLot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
   double requiredMargin = lot * marginRequiredPerLot;

   if (AccountInfoDouble(ACCOUNT_FREEMARGIN) < requiredMargin)
   {
      Print("[ERROR] Margine insufficiente. Riduzione lotto...");
      lot = AccountInfoDouble(ACCOUNT_FREEMARGIN) / marginRequiredPerLot;
      lot = MathFloor(lot / lotStep) * lotStep;

      if (lot < minLot)
      {
         Print("[FATAL] Lotto minimo non raggiungibile. Lotto finale: ", lot);
         return 0.0;
      }
   }

   return NormalizeDouble(lot, 2);
}

// === Verifica se si può aprire un nuovo ordine ===
bool CanOpenNewTrade()
{
   int count = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (PositionGetTicket(i) > 0)
      {
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
         if (posSymbol == _Symbol && magic == (ulong)MagicNumber)
            count++;
      }
   }

   if (count >= MaxOpenTrades)
   {
      LogInfo("🚫 MaxOpenTrades raggiunto per " + _Symbol + ": " + IntegerToString(count));
      return false;
   }

   return true;
}

#endif
