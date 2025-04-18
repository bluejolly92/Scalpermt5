//+------------------------------------------------------------------+
//| Utils.mqh - Funzioni ausiliarie                                 |
//+------------------------------------------------------------------+
#ifndef __UTILS_MQH__
#define __UTILS_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/Logger.mqh>

bool IsTradingHour()
{
   datetime now = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(now, t);
   return (t.hour >= StartHour && t.hour < EndHour);
}

bool IsVolatilitySufficient()
{
   double atr = iATR(_Symbol, PERIOD_M15, ATR_Period);
   LogDebug("Volatilità attuale (ATR): " + DoubleToString(atr, 5));

   if (atr < MinATR)
   {
      LogDebug("❌ Volatilità insufficiente: ATR < MinATR");
      return false;
   }

   LogDebug("✅ Volatilità sufficiente");
   return true;
}

string ErrorDescription(int code)
{
   switch(code)
   {
      case 1: return "No error returned";
      case 2: return "Common error";
      case 3: return "Invalid trade parameters";
      case 4: return "Trade server is busy";
      case 5: return "Old version of the client terminal";
      case 6: return "No connection with trade server";
      case 8: return "Too frequent requests";
      case 64: return "Account disabled";
      case 133: return "Trading is disabled";
      case 134: return "Not enough money";
      case 135: return "Price changed";
      case 136: return "No prices";
      case 137: return "Broker is busy";
      case 138: return "Requote";
      case 139: return "Order locked";
      case 146: return "Trade context busy";
      case 148: return "Too many requests";
      default: return "Errore sconosciuto (" + IntegerToString(code) + ")";
   }
}

#endif
