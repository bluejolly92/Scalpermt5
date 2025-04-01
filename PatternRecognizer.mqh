//+------------------------------------------------------------------+
//| PatternRecognizer.mqh - Pattern Engulfing                        |
//+------------------------------------------------------------------+
#ifndef __PATTERN_RECOGNIZER_MQH__
#define __PATTERN_RECOGNIZER_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/Logger.mqh>

// === Rilevamento Pattern Engulfing ===
bool IsEngulfingSignal()
{
   if (!EnableEngulfing)
   {
      LogDebug("ℹ️ Engulfing disabilitato da input.");
      return false;
   }

   // === Calcolo ATR ===
   int atrHandle = iATR(_Symbol, PERIOD_H1, ATR_Period);
   if (atrHandle == INVALID_HANDLE)
   {
      LogError("❌ Errore creazione handle ATR H1");
      return false;
   }

   double atrBuffer[];
   if (CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
   {
      LogError("❌ Errore lettura buffer ATR H1");
      return false;
   }

   double atrH1 = atrBuffer[0];
   if (atrH1 < MinATR)
   {
      LogDebug("📏 ATR H1 troppo basso per pattern Engulfing: " + DoubleToString(atrH1, 5));
      return false;
   }

   // === Controllo Pattern ===
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   int shift = 1;

   double open1  = iOpen(_Symbol, tf, shift + 1);
   double close1 = iClose(_Symbol, tf, shift + 1);
   double open2  = iOpen(_Symbol, tf, shift);
   double close2 = iClose(_Symbol, tf, shift);

   bool isBullishEngulfing = (close1 < open1 && close2 > open2 && close2 > open1 && open2 < close1);
   bool isBearishEngulfing = (close1 > open1 && close2 < open2 && close2 < open1 && open2 > close1);

   if (isBullishEngulfing)
   {
      LogInfo("✅ Pattern Engulfing Bullish rilevato.");
      return true;
   }

   if (isBearishEngulfing)
   {
      LogInfo("✅ Pattern Engulfing Bearish rilevato.");
      return true;
   }

   LogDebug("📉 Nessun pattern Engulfing rilevato.");
   return false;
}

#endif