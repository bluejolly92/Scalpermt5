//+------------------------------------------------------------------+
//| RiskManager.mqh - Calcolo SL/TP e Lotto Dinamico                |
//+------------------------------------------------------------------+
#ifndef __RISK_MANAGER_MQH__
#define __RISK_MANAGER_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/Logger.mqh>

int atrHandleM15 = INVALID_HANDLE;
double lastATR = 0.0;
datetime lastATRCalc = 0;

// === Funzione di inizializzazione ATR ===
bool InitATR()
{
   atrHandleM15 = iATR(_Symbol, PERIOD_M15, ATR_Period);
   if (atrHandleM15 == INVALID_HANDLE)
   {
      LogError("❌ Impossibile creare handle ATR M15");
      return false;
   }
   return true;
}

// === Funzione Cleanup ATR ===
void ReleaseATR()
{
   if (atrHandleM15 != INVALID_HANDLE)
   {
      IndicatorRelease(atrHandleM15);
      atrHandleM15 = INVALID_HANDLE;
   }
}

// === Calcolo ATR con caching per performance ===
double GetCachedATR()
{
   MqlRates rates[];
   if (CopyRates(_Symbol, PERIOD_M15, 0, 1, rates) <= 0) 
   {
      LogError("❌ Errore nella lettura dei dati Rates per ATR");
      return 0.0;
   }

   if (lastATRCalc == rates[0].time)
      return lastATR;

   double atrBuffer[];
   if (CopyBuffer(atrHandleM15, 0, 0, 1, atrBuffer) <= 0)
   {
      LogError("❌ Errore nella lettura buffer ATR");
      return 0.0;
   }

   lastATR = atrBuffer[0];
   lastATRCalc = rates[0].time;

   return lastATR;
}

// === Calcolo SL/TP dinamici ===
bool CalculateDynamicSLTP(bool isBuy, double &sl, double &tp)
{
   double atr = GetCachedATR();
   if (atr <= 0.0 || atr < MinATR)
   {
      LogDebug("❌ ATR troppo basso o nullo per SL/TP: " + DoubleToString(atr, 5));
      return false;
   }

   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slOffset = atr * SL_ATR_Mult;
   double tpOffset = atr * TP_ATR_Mult;

   sl = NormalizeDouble(isBuy ? price - slOffset : price + slOffset, _Digits);
   tp = NormalizeDouble(isBuy ? price + tpOffset : price - tpOffset, _Digits);

   LogDebug("📐 SL/TP calcolati → SL: " + DoubleToString(sl, _Digits) + " | TP: " + DoubleToString(tp, _Digits));
   return true;
}

// === Calcolo lotto dinamico ===
double CalculateLotSize(double stopLossPrice, bool isBuy, double riskPercent)
{
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance = MathAbs(price - stopLossPrice);

   double minSLDistance = _Point * 10;
   slDistance = fmax(slDistance, minSLDistance);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100.0;

   double lot = riskAmount / (slDistance / _Point * tickValue);

   double maxLot = LotSizeMax;
   double minLot = LotSizeMin;
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathMin(maxLot, MathFloor(lot / lotStep) * lotStep);
   lot = MathMax(lot, minLot);

   double marginRequiredPerLot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
   double requiredMargin = lot * marginRequiredPerLot;

   if (AccountInfoDouble(ACCOUNT_FREEMARGIN) < requiredMargin)
   {
      LogError("[ERROR] Margine insufficiente. Riduzione lotto...");
      lot = AccountInfoDouble(ACCOUNT_FREEMARGIN) / marginRequiredPerLot;
      lot = MathFloor(lot / lotStep) * lotStep;

      if (lot < minLot)
      {
         LogError("[FATAL] Lotto minimo non raggiungibile. Lotto finale: " + DoubleToString(lot, 2));
         return 0.0;
      }
   }

   return NormalizeDouble(lot, 2);
}

#endif
