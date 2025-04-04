//+------------------------------------------------------------------+
//| Inputs.mqh - Parametri esterni configurabili                    |
//+------------------------------------------------------------------+
#ifndef __INPUTS_MQH__
#define __INPUTS_MQH__

// === Impostazioni Generali ===
input int    MagicNumber            = 123456;
input bool   EnableLogging          = true;
input bool   EnableVerboseLog       = false;
input int    LogThrottleSeconds     = 10;
input bool   EnableGUI              = true;

// === Gestione Rischio ===
input double RiskPercent            = 2.0;
input double LotSizeMin             = 0.01;
input double LotSizeMax             = 5.0;
input int    MaxOpenTrades          = 3;
input int    Slippage               = 10;
input bool   EnableActiveZoneBlock = true; // Blocco apertura in zona attiva (tra SL e TP esistenti)

// === Strategia Breakout ===
input bool   EnableBreakout         = true;
input int    ATR_Period             = 14;
input double SL_ATR_Mult            = 1.5;
input double TP_ATR_Mult            = 2.0;

// === Pattern Engulfing ===
input bool   EnableEngulfing        = true;

// === Filtri Trend ===
input bool   EnableTrendFilter      = true;
input bool   EnableMAFilter         = true;
input int    MA_Period              = 50;
input int    MA_Direction           = 0;       // 1 = solo long, -1 = solo short, 0 = entrambi
input bool   EnableADXFilter        = true;
input int    ADX_Period             = 14;
input double ADX_Threshold          = 20.0;
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_H1; // 60 = H1

// === Filtri Volatilità ===
input double MinATR                 = 0.0005;

// === Filtri News e Orari Operativi ===
input bool   EnableNewsFilter       = false;
input int    NewsBlockMinutes       = 5;
input bool   EnableTradingHours     = true;
input int    StartHour              = 8;
input int    EndHour                = 20;

// === Gestione Trailing e Break-even ===
input bool   EnableTrailing         = true;
input double TrailingATRMultiplier = 1.0;
input int    TrailingATRPeriod      = 14;
input double TrailingActivationPct = 50.0;    // % di distanza TP per attivare trailing
input double TrailingThrottleFactor = 0.2;    // distanza minima tra update, moltiplicatore di ATR

input bool   EnableBreakEven        = true;
input double BreakEvenPct           = 40.0;    // % di distanza TP per attivare break-even

#endif