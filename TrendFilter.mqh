//+------------------------------------------------------------------+
//| TrendFilter.mqh - Filtro MA e ADX per confermare il trend       |
//+------------------------------------------------------------------+
#ifndef __TREND_FILTER_MQH__
#define __TREND_FILTER_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/Logger.mqh>

bool IsTrendConfirmed()
{
   if (!EnableTrendFilter)
   {
      LogDebug("ℹ️ Filtro Trend disattivato.");
      return true;
   }

   bool maOk = true;
   bool adxOk = true;

   // --- Filtro MA ---
   if (EnableMAFilter)
   {
      int maHandle = iMA(_Symbol, (ENUM_TIMEFRAMES)TrendTimeframe, MA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if (maHandle == INVALID_HANDLE)
      {
         LogError("❌ Errore creazione handle MA");
         maOk = false;
      }
      else
      {
         double maBuffer[];
         if (CopyBuffer(maHandle, 0, 0, 1, maBuffer) <= 0)
         {
            LogError("❌ Errore lettura MA");
            maOk = false;
         }
         else
         {
            double ma = maBuffer[0];
            double price = iClose(_Symbol, (ENUM_TIMEFRAMES)TrendTimeframe, 0);

            LogDebug("📊 MA(" + IntegerToString(MA_Period) + ", TF: " + IntegerToString(TrendTimeframe) + ") = " +
                     DoubleToString(ma, _Digits) + " | Prezzo = " + DoubleToString(price, _Digits));

            if (MA_Direction == 1 && price <= ma)
               maOk = false;
            else if (MA_Direction == -1 && price >= ma)
               maOk = false;
         }
      }
   }

   // --- Filtro ADX ---
   if (EnableADXFilter)
   {
      int adxHandle = iADX(_Symbol, (ENUM_TIMEFRAMES)TrendTimeframe, ADX_Period);
      if (adxHandle == INVALID_HANDLE)
      {
         LogError("❌ Errore creazione handle ADX");
         adxOk = false;
      }
      else
      {
         double adxBuffer[];
         if (CopyBuffer(adxHandle, 0, 0, 1, adxBuffer) <= 0)
         {
            LogError("❌ Errore lettura ADX");
            adxOk = false;
         }
         else
         {
            double adx = adxBuffer[0];
            LogDebug("📈 ADX(" + IntegerToString(ADX_Period) + ", TF: " + IntegerToString(TrendTimeframe) + ") = " +
                     DoubleToString(adx, 2));

            if (adx < ADX_Threshold)
               adxOk = false;
         }
      }
   }

   if (!maOk || !adxOk)
   {
      LogDebug("⛔️ Trend non confermato → MA: " + (maOk ? "✅" : "❌") + " | ADX: " + (adxOk ? "✅" : "❌"));
      return false;
   }

   LogDebug("✅ Trend confermato da filtri attivi.");
   return true;
}


#endif