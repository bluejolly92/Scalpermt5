//+------------------------------------------------------------------+
//| BreakoutEngine.mqh - Logica per segnali breakout                |
//+------------------------------------------------------------------+
#ifndef __BREAKOUT_ENGINE_MQH__
#define __BREAKOUT_ENGINE_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/Logger.mqh>
#include <Scalpermt5/RiskManager.mqh>

bool CheckBreakoutSignal(double &sl, double &tp)
{
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   double high_prev = iHigh(_Symbol, tf, 1);
   double low_prev  = iLow(_Symbol, tf, 1);
   double high_curr = iHigh(_Symbol, tf, 0);
   double low_curr  = iLow(_Symbol, tf, 0);

   // Breakout LONG
   if (high_curr > high_prev)
   {
      if (!CalculateDynamicSLTP(true, sl, tp))
      {
         LogDebug("❌ SL/TP non calcolabili per breakout LONG");
         return false;
      }

      LogInfo("📈 Breakout LONG rilevato - SL: " + DoubleToString(sl, _Digits) + " | TP: " + DoubleToString(tp, _Digits));
      return true;
   }

   // Breakout SHORT
   if (low_curr < low_prev)
   {
      if (!CalculateDynamicSLTP(false, sl, tp))
      {
         LogDebug("❌ SL/TP non calcolabili per breakout SHORT");
         return false;
      }

      LogInfo("📉 Breakout SHORT rilevato - SL: " + DoubleToString(sl, _Digits) + " | TP: " + DoubleToString(tp, _Digits));
      return true;
   }

   LogDebug("Nessun breakout rilevato. HighCurr: " + DoubleToString(high_curr, _Digits) +
            " | LowCurr: " + DoubleToString(low_curr, _Digits) +
            " | HighPrev: " + DoubleToString(high_prev, _Digits) +
            " | LowPrev: " + DoubleToString(low_prev, _Digits));
   return false;
}

#endif
