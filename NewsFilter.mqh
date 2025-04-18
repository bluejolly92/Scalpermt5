//+------------------------------------------------------------------+
//| NewsFilter.mqh - Blocco operatività in orari sensibili          |
//+------------------------------------------------------------------+
#ifndef __NEWS_FILTER_MQH__
#define __NEWS_FILTER_MQH__

#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/Logger.mqh>

// === Rilevamento orario di blocco per simulazione eventi macro ===
bool IsNewsTime()
{
   if (!EnableNewsFilter)
   {
      LogDebug("🛑 Filtro news disattivato.");
      return false;
   }

   datetime now = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(now, tm);

   if (tm.min >= 0 && tm.min < NewsBlockMinutes)
   {
      LogInfo("📰 NewsTime → Blocco attivo nei primi " + IntegerToString(NewsBlockMinutes) +
              " min dell'ora. Ora corrente: " + TimeToString(now, TIME_MINUTES));
      return true;
   }

   return false;
}

#endif