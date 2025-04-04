//+------------------------------------------------------------------+
//| PatternRecognizer.mqh - Pattern Engulfing                        |
//+------------------------------------------------------------------+
#ifndef __PATTERN_RECOGNIZER_MQH__
#define __PATTERN_RECOGNIZER_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/Logger.mqh>
#include <Scalpermt5/RiskManager.mqh> // Per usare GetCachedATR

// === Rilevamento Pattern Engulfing ===
bool IsEngulfingSignal(bool &isBuy)
{
   if (!EnableEngulfing)
   {
      LogDebug("ℹ️ Engulfing disabilitato da input.");
      return false;
   }

   int shift = 1;
   double open1  = iOpen(_Symbol, _Period, shift + 1);
   double close1 = iClose(_Symbol, _Period, shift + 1);
   double open2  = iOpen(_Symbol, _Period, shift);
   double close2 = iClose(_Symbol, _Period, shift);

   double atr = GetCachedATR();
   if (atr < MinATR)
   {
      LogDebug("📏 ATR troppo basso per pattern Engulfing: " + DoubleToString(atr, 5));
      return false;
   }

   bool isBullish = (close1 < open1 && close2 > open2 && close2 > open1 && open2 < close1);
   bool isBearish = (close1 > open1 && close2 < open2 && close2 < open1 && open2 > close1);

   if (isBullish)
   {
      isBuy = true;
      LogInfo("✅ Pattern Engulfing Bullish rilevato.");
      return true;
   }

   if (isBearish)
   {
      isBuy = false;
      LogInfo("✅ Pattern Engulfing Bearish rilevato.");
      return true;
   }

   LogDebug("📉 Nessun pattern Engulfing rilevato.");
   return false;
}

#endif