//+------------------------------------------------------------------+
//| LiquidityTrader_ModeDisplay_ScoreLog.mq4                         |
//| PSAR exit logic and no Take Profit version                      |
//+------------------------------------------------------------------+
#property strict

#include <stdlib.mqh>
#include <stderror.mqh>

input int LookBackBars = 20;
input double ATR_Multiplier = 1.5;
input double RiskPercent = 2.0;
input int MagicNumber = 123456;
input string TradeMode = "SweepOnly";
input int ZoneLockBars = 3;
input bool ConfirmOnClose = false;
input double EntryScoreThreshold = 3.0;
input string LogFileName = "TradeLog.csv";

//--- Globals

double atrValue;
double zoneHigh, zoneLow;
double lockedZoneHigh, lockedZoneLow;
int zoneLockCounter = 0;
datetime lastTradeCloseTime = 0;
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

   if (OrdersTotal() == 0) {
      if ((TradeMode == "SweepOnly" || TradeMode == "Both") && scoreBuy >= EntryScoreThreshold) {
         LogTradeDetails("BUY", scoreBuy, scoreNotesBuy);
         LockZoneAndTrade(OP_BUY, scoreBuy);
      }
      if ((TradeMode == "SweepOnly" || TradeMode == "Both") && scoreSell >= EntryScoreThreshold) {
         LogTradeDetails("SELL", scoreSell, scoreNotesSell);
         LockZoneAndTrade(OP_SELL, scoreSell);
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

double ScoreSweep(int direction, int bar) {
   double score = 0;
   double adx = iADX(Symbol(), PERIOD_D1, 14, PRICE_CLOSE, MODE_MAIN, bar);
   double plusDI = iADX(Symbol(), PERIOD_D1, 14, PRICE_CLOSE, MODE_PLUSDI, bar);
   double minusDI = iADX(Symbol(), PERIOD_D1, 14, PRICE_CLOSE, MODE_MINUSDI, bar);
   string notes = "";

   if (direction == OP_BUY) {
      if (plusDI <= minusDI) {
         scoreNotesBuy = "Blocked by DI+ <= DI-";
         return 0;
      }
      if (Low[bar] < zoneLow && Close[bar] > zoneLow) { score += 2; notes += "Wick Sweep + "; }
      if (Close[bar] > Open[bar] && (Open[bar] - Low[bar]) > (Close[bar] - Open[bar])) { score += 1; notes += "Body/Wick + "; }
      if (adx < 20) { score += 1; notes += "Low ADX + "; }
      if (Close[bar + 1] > Close[bar]) { score += 2; notes += "Bull Confirm + "; }
      scoreNotesBuy = notes;
   } else {
      if (minusDI <= plusDI) {
         scoreNotesSell = "Blocked by DI- <= DI+";
         return 0;
      }
      if (High[bar] > zoneHigh && Close[bar] < zoneHigh) { score += 2; notes += "Wick Sweep + "; }
      if (Close[bar] < Open[bar] && (High[bar] - Open[bar]) > (Open[bar] - Close[bar])) { score += 1; notes += "Body/Wick + "; }
      if (adx < 20) { score += 1; notes += "Low ADX + "; }
      if (Close[bar + 1] < Close[bar]) { score += 2; notes += "Bear Confirm + "; }
      scoreNotesSell = notes;
   }
   return score;
}

void LockZoneAndTrade(int orderType, double score) {
   zoneIsLocked = true;
   lockedZoneHigh = zoneHigh;
   lockedZoneLow = zoneLow;
   zoneLockCounter = ZoneLockBars;
   EnterTrade(orderType, score);
}

void EnterTrade(int orderType, double score) {
   double entry = orderType == OP_BUY ? Ask : Bid;
   double sl = orderType == OP_BUY ? entry - atrValue * ATR_Multiplier : entry + atrValue * ATR_Multiplier;

   double pipSize = 0.0001;
   double pipValuePerLot = 10.0;
   double riskAmount = AccountBalance() * (RiskPercent / 100.0);
   double stopLossPips = MathAbs(entry - sl) / pipSize;
   double lots = NormalizeDouble(riskAmount / (stopLossPips * pipValuePerLot), 2);

   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   lots = MathMax(minLot, MathMin(maxLot, MathFloor(lots / lotStep) * lotStep));

   Print("Risk: ", riskAmount, " | SL(pips): ", stopLossPips, " | Lots: ", lots);

   int ticket = OrderSend(Symbol(), orderType, lots, entry, 3, sl, 0, "Liquidity Trade", MagicNumber, 0,
                          orderType == OP_BUY ? clrBlue : clrRed);

   if (ticket > 0) {
      DrawTradeLines(entry, sl, 0, orderType);
      LogTradeResult(entry, sl, 0, lots, score, orderType);
   } else {
      Print("OrderSend failed: ", GetLastError());
   }
}

void DrawTradeLines(double entry, double sl, double tp, int orderType) {
   color lineColor = orderType == OP_BUY ? clrBlue : clrRed;
   DrawHLine("EntryLine", entry, lineColor);
   DrawHLine("StopLossLine", sl, clrRed);
}

void CleanupTradeLines() {
   for (int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MagicNumber) {
         if (OrderCloseTime() > lastTradeCloseTime) {
            lastTradeCloseTime = OrderCloseTime();
            ObjectDelete("EntryLine");
            ObjectDelete("StopLossLine");
         }
      }
   }
}

void DrawHLine(string name, double price, color clr) {
   if (ObjectFind(0, name) >= 0) ObjectDelete(name);
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
}

void DrawLiquidityZones() {
   string name = "LiquidityZone";
   if (ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, Time[LookBackBars], zoneHigh, Time[1], zoneLow);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkSlateGray);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   } else {
      ObjectMove(0, name, 0, Time[LookBackBars], zoneHigh);
      ObjectMove(0, name, 1, Time[1], zoneLow);
   }
}

void LogTradeDetails(string direction, double score, string notes) {
   int handle = FileOpen(LogFileName, FILE_CSV | FILE_READ | FILE_WRITE, ',');
   if (handle != INVALID_HANDLE) {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), Symbol(), direction, score, notes, zoneHigh, zoneLow);
      FileClose(handle);
   }
}

void LogTradeResult(double entry, double sl, double tp, double lots, double score, int orderType) {
   int handle = FileOpen(LogFileName, FILE_CSV | FILE_READ | FILE_WRITE, ',');
   if (handle != INVALID_HANDLE) {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), Symbol(),
                orderType == OP_BUY ? "BUY" : "SELL", score, entry, sl, tp, lots, zoneHigh, zoneLow);
      FileClose(handle);
   }
}
