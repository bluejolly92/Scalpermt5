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

   // Breakout
   if (EnableBreakout && CheckBreakoutSignal(sl, tp))
   {
      LogThrottled("🚨 Segnale breakout rilevato.");
      isBuy = iClose(_Symbol, _Period, 0) > iHigh(_Symbol, _Period, 1);
      tradeSignal = true;
   }
   // Pattern Engulfing
   else if (EnableEngulfing && IsEngulfingSignal(isBuy))
   {
      LogThrottled("🚨 Pattern engulfing rilevato.");
      if(!CalculateDynamicSLTP(isBuy, sl, tp))
      {
         LogError("❌ SL/TP impossibile da calcolare.");
         return;
      }
      tradeSignal = true;
   }

   if (tradeSignal)
   {
      if (EnableActiveZoneBlock && IsInActiveTradeZone(sl, tp))
      {
         LogInfo("🚫 Ordine in zona SL–TP attiva.");
         return;
      }

      double lot = CalculateLotSize(sl, isBuy, RiskPercent);
      if(lot <= 0.0)
      {
         LogError("❌ Lotto invalido.");
         return;
      }

      if (!OpenTrade(isBuy, sl, tp))
         LogError("❌ Errore apertura trade.");
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