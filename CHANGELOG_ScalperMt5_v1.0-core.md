# 📄 Changelog – ScalperMt5

## [v1.0-core] - 2025-04-04
### 🚀 Feature completate
- ✅ Fase 0: Inizializzazione EA, gestione handle ATR, verbose log
- ✅ Fase 1: Apertura ordini BUY/SELL basata su candela precedente, ATR per SL/TP, lotto dinamico con rischio
- ✅ Fase 2: Trailing Stop attivato da % TP, protezione anti-sl widening, throttling in pips
- ✅ Fase 3: BreakEven semplice, attivazione una tantum, offset configurabile
- ✅ Fase 4.2: Lock Protection – apertura posizione contraria su % TP, SL/TP simmetrici
- ✅ Fase 4.3: Step TP – aggiornamento dinamico TP + trailing SL per seguire il trend

### 🔧 Ottimizzazioni
- Logging migliorato per debugging (SL, TP, trailing, lock, BE)
- Protezione contro ripetizioni (flag interni per lock e BE)
- Ordine delle operazioni rivisto: ApplyTrailingStop() prima di aperture

### 🔬 Test
- Backtest su EURUSD H1 e M15 (2021–2024)
- Verificato: ordine singolo alla volta, attivazioni una tantum funzionanti

---
📌 Prossimo passo: Fase 5 – Filtri Operativi (Trend, ATR, Orario)
