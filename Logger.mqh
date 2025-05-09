//+------------------------------------------------------------------+
//| Logger.mqh - Logging con gestione per tipo                       |
//+------------------------------------------------------------------+
#ifndef __LOGGER_MQH__
#define __LOGGER_MQH__
#define LogWarning(msg) Print("[WARNING] " + msg)

#include <Scalpermt5/Inputs.mqh>

string lastLogMsg = "";
datetime lastLogTime = 0;

// === Logging con throttling (escludendo errori gravi) ===
void LogThrottled(string message, bool force = false)
{
   datetime currentTime = TimeCurrent();
   if (force || message != lastLogMsg || (currentTime - lastLogTime) >= LogThrottleSeconds)
   {
      Print(message);
      lastLogMsg = message;
      lastLogTime = currentTime;
   }
}

// === Log informativo ===
void LogInfo(string message)
{
   LogThrottled("[INFO] " + message);
}

// === Log di successo importante ===
void LogSuccess(string message)
{
   LogThrottled("[SUCCESS] " + message);
}

// === Log errori e criticità (senza throttling) ===
void LogError(string message)
{
   LogThrottled("[ERROR] " + message, true);  // forzato
}

// === Log diagnostico avanzato (verbose mode) ===
void LogDebug(string message)
{
   if (EnableVerboseLog)
      LogThrottled("[DEBUG] " + message);
}

#endif
