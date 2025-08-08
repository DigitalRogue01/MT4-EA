//+------------------------------------------------------------------+
//| LiquidityTrader_ModeDisplay_ScoreLog.mq4                         |
//| PSAR exit logic and PSAR-based entry bonus (trend filter removed)|
//+------------------------------------------------------------------+
#property strict

#include <stdlib.mqh>
#include <stderror.mqh>

input int LookBackBars = 20;
input double ATR_Multiplier = 1.5;
input double RiskPercent = 2.0;
input int MagicNumber = 123456;
input string TradeMode = "Both";
input int ZoneLockBars = 3;
input bool ConfirmOnClose = false;
input double EntryScoreThreshold = 2.0;
input string LogFileName = "TradeLog.csv";

//--- Globals

double atrValue;
double zoneHigh, zoneLow;
double lockedZoneHigh, lockedZoneLow;
int zoneLockCounter = 0;
datetime lastTradeCloseTime = 0;
datetime lastTradeTime = 0;
bool zoneIsLocked = false;
string scoreNotesBuy = "", scoreNotesSell = "";

int OnInit() {
   ObjectsDeleteAll(0, OBJ_RECTANGLE);
   return(INIT_SUCCEEDED);
}

void OnTick() {
   if (Bars < LookBackBars + 10 || Time[0] == Time[1]) return;

   atrValue = iATR(Symbol(), PERIOD_D1, 14, 0);

   if (zoneLockCounter > 0 && zoneIsLocked) {
      zoneHigh = lockedZoneHigh;
      zoneLow = lockedZoneLow;
      zoneLockCounter--;
      if (zoneLockCounter == 0) zoneIsLocked = false;
   } else {
      zoneHigh = High[iHighest(Symbol(), PERIOD_D1, MODE_HIGH, LookBackBars, 1)];
      zoneLow = Low[iLowest(Symbol(), PERIOD_D1, MODE_LOW, LookBackBars, 1)];
   }

   DrawLiquidityZones();
   CleanupTradeLines();

   CheckPSARExit();

   int bar = ConfirmOnClose ? 1 : 0;
   double scoreBuy = ScoreSweep(OP_BUY, bar);
   double scoreSell = ScoreSweep(OP_SELL, bar);

   if (OrdersTotal() == 0 && Time[0] != lastTradeTime) {
      if ((TradeMode == "SweepOnly" || TradeMode == "Both") && scoreBuy >= EntryScoreThreshold) {
         LogTradeDetails("BUY", scoreBuy, scoreNotesBuy);
         LockZoneAndTrade(OP_BUY, scoreBuy);
         lastTradeTime = Time[0];
      }
      if ((TradeMode == "SweepOnly" || TradeMode == "Both") && scoreSell >= EntryScoreThreshold) {
         LogTradeDetails("SELL", scoreSell, scoreNotesSell);
         LockZoneAndTrade(OP_SELL, scoreSell);
         lastTradeTime = Time[0];
      }
   }

   Comment("Balance: $", AccountBalance(),
           "\nATR(14): ", DoubleToString(atrValue, 5),
           "\nZone High: ", DoubleToString(zoneHigh, Digits),
           " | Zone Low: ", DoubleToString(zoneLow, Digits),
           "\nZone Lock Bars Left: ", zoneLockCounter,
           "\nTradeMode: ", TradeMode,
           "\nBuy Score: ", scoreBuy, " | ", scoreNotesBuy,
           "\nSell Score: ", scoreSell, " | ", scoreNotesSell);
}

void CheckPSARExit() {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) {
            double psar = iSAR(Symbol(), PERIOD_D1, 0.02, 0.2, 0);
            if (OrderType() == OP_BUY && psar > Bid) {
               OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed);
               Print("PSAR Exit BUY at ", Bid);
            } else if (OrderType() == OP_SELL && psar < Ask) {
               OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrRed);
               Print("PSAR Exit SELL at ", Ask);
            }
         }
      }
   }
}

void DrawLiquidityZones() {
   string boxName = "LiquidityZoneBox";
   if (!ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, Time[LookBackBars], zoneLow, Time[1], zoneHigh)) {
      ObjectMove(0, boxName, 0, Time[LookBackBars], zoneLow);
      ObjectMove(0, boxName, 1, Time[1], zoneHigh);
   }
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
}

void CleanupTradeLines() {
   // Placeholder: remove objects related to closed trades
}

void LogTradeDetails(string direction, double score, string notes) {
   // Placeholder: log trade score and notes to CSV file
}

double ScoreSweep(int type, int bar) {
   double score = 0;
   double psar = iSAR(Symbol(), PERIOD_D1, 0.02, 0.2, bar);

   if (type == OP_BUY) {
      scoreNotesBuy = "";
      if (Close[bar] < zoneLow || Low[bar] < zoneLow) {
         score += 2;
         scoreNotesBuy = "Buy Zone Break";
      }
      if (psar < Close[bar]) {
         score += 1;
         if (scoreNotesBuy != "") scoreNotesBuy += " + ";
         scoreNotesBuy += "PSAR Bonus";
      }
      return score;
   } else {
      scoreNotesSell = "";
      if (Close[bar] > zoneHigh || High[bar] > zoneHigh) {
         score += 2;
         scoreNotesSell = "Sell Zone Break";
      }
      if (psar > Close[bar]) {
         score += 1;
         if (scoreNotesSell != "") scoreNotesSell += " + ";
         scoreNotesSell += "PSAR Bonus";
      }
      return score;
   }
}

void LockZoneAndTrade(int type, double score) {
   double slBuffer = atrValue * ATR_Multiplier;
   double sl = 0, entry = 0;
   double lotSize = NormalizeDouble((AccountBalance() * RiskPercent / 100.0) / slBuffer, 2);

   if (type == OP_BUY) {
      entry = Ask;
      sl = entry - slBuffer;
   } else {
      entry = Bid;
      sl = entry + slBuffer;
   }

   int ticket = OrderSend(Symbol(), type, lotSize, entry, 3, sl, 0, "LiquidityEntry", MagicNumber, 0, clrBlue);
   if (ticket < 0) Print("OrderSend failed with error #", GetLastError());

   lockedZoneHigh = zoneHigh;
   lockedZoneLow = zoneLow;
   zoneLockCounter = ZoneLockBars;
   zoneIsLocked = true;
}
