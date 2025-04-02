//+------------------------------------------------------------------+
//| Scalpermt5.mq5 - Expert Advisor principale                       |
//+------------------------------------------------------------------+
#property strict
#property copyright "Andrea Pitzianti"
#property link      "https://github.com/bluejolly92/ScalperMt4"
#property version   "1.00"

// === INCLUDES ===
#include <Scalpermt5/Inputs.mqh>
#include <Scalpermt5/BreakoutEngine.mqh>
#include <Scalpermt5/PatternRecognizer.mqh>
#include <Scalpermt5/RiskManager.mqh>
#include <Scalpermt5/TradeManager.mqh>
#include <Scalpermt5/NewsFilter.mqh>
#include <Scalpermt5/GUI.mqh>
#include <Scalpermt5/Logger.mqh>
#include <Scalpermt5/TrendFilter.mqh>
#include <Scalpermt5/Utils.mqh>

datetime lastTradeTime = 0;
string   lastSignalType = "";
int      throttleSeconds = 30; // intervallo minimo tra due segnali identici

//+------------------------------------------------------------------+
//| Funzione di inizializzazione                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   if (EnableLogging)
      Print("✅ EA inizializzato correttamente");

   if (EnableGUI)
      InitGUI();

   if (!InitATR())
   {
      LogError("❌ Fallimento inizializzazione ATR. EA non avviato.");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Funzione principale di esecuzione su ogni tick                   |
//+------------------------------------------------------------------+
void OnTick()
{
   double sl = 0.0, tp = 0.0;

   if (EnableTradingHours && !IsTradingHour())
   {
      LogInfo("⏰ Orario non operativo.");
      return;
   }

   if (IsNewsTime())
   {
      LogInfo("📢 Blocco news attivo.");
      return;
   }

   if (!IsVolatilitySufficient())
   {
      LogInfo("❌ Volatilità insufficiente.");
      return;
   }

   if (!IsTrendConfirmed())
   {
      LogInfo("❌ Filtro trend non confermato.");
      return;
   }

   if (!CanOpenNewTrade())
   {
      LogInfo("🚫 Limite massimo ordini raggiunto.");
      ManageOpenTrades(); 
      UpdateGUI();
      return;
   }

   bool tradeSignal = false;
   bool isBuy = false;
   string currentSignalType = "";

   if (EnableBreakout && CheckBreakoutSignal(sl, tp))
   {
      currentSignalType = "breakout";
      LogThrottled("🚨 Segnale breakout rilevato.");
      isBuy = iClose(_Symbol, _Period, 0) > iHigh(_Symbol, _Period, 1);
      tradeSignal = true;
   }
   else if (EnableEngulfing && IsEngulfingSignal(isBuy))
   {
      currentSignalType = "engulfing";
      LogThrottled("🚨 Pattern engulfing rilevato.");
      if (!CalculateDynamicSLTP(isBuy, sl, tp))
      {
         LogError("❌ SL/TP impossibile da calcolare.");
         return;
      }
      tradeSignal = true;
   }
   
   if (tradeSignal)
   {
      int secondsSinceLastTrade = (int)(TimeCurrent() - lastTradeTime);

      if (secondsSinceLastTrade < throttleSeconds && currentSignalType == lastSignalType)
      {
         LogInfo(StringFormat("⏳ Segnale ignorato. Cooldown attivo: %d secondi rimanenti.", throttleSeconds - secondsSinceLastTrade));
         return;
      }

      LogInfo("📨 Tentativo apertura ordine...");

      bool tradeOpened = OpenTrade(isBuy, sl, tp);

      if (tradeOpened)
      {
         lastTradeTime = TimeCurrent();
         lastSignalType = currentSignalType;
         LogInfo("✅ Trade aperto. Cooldown aggiornato.");
      }
      else
      {
         LogWarning("⚠️ Trade non aperto. Cooldown NON aggiornato.");
      }
   }

   ManageOpenTrades(); 
   UpdateGUI();
}

//+------------------------------------------------------------------+
//| Funzione di deinizializzazione                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ReleaseATR();

   if (EnableGUI)
      CleanupGUI();

   if (EnableLogging)
      Print("🛑 EA terminato");
}