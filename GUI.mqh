//+------------------------------------------------------------------+
//| GUI.mqh - Visualizzazione diagnostica su chart                  |
//+------------------------------------------------------------------+
#ifndef __GUI_MQH__
#define __GUI_MQH__

#include <Scalpermt5/Inputs.mqh>

string guiLabelName = "Scalpermt5_Status";

void InitGUI()
{
   if (!EnableGUI) return;

   if (!ObjectCreate(0, guiLabelName, OBJ_LABEL, 0, 0, 0))
      Print("Errore nella creazione dell'oggetto GUI: ", GetLastError());

   ObjectSetInteger(0, guiLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, guiLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, guiLabelName, OBJPROP_YDISTANCE, 10);
   ObjectSetInteger(0, guiLabelName, OBJPROP_COLOR, clrWhite);
   ObjectSetString(0, guiLabelName, OBJPROP_TEXT, "🟢 Scalpermt5 inizializzato");
   ObjectSetInteger(0, guiLabelName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, guiLabelName, OBJPROP_FONT, "Arial");
}

void UpdateGUI()
{
   if (!EnableGUI || ObjectFind(0, guiLabelName) < 0) return;

   string content = "🧠 EA attivo\n";
   content += "Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
   content += "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   content += "Time: " + TimeToString(TimeCurrent(), TIME_MINUTES);

   ObjectSetString(0, guiLabelName, OBJPROP_TEXT, content);
}

void CleanupGUI()
{
   ObjectDelete(0, guiLabelName);
}

#endif