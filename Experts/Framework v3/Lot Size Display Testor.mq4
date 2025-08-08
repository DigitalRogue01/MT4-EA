//+------------------------------------------------------------------+
//|                                               LotSizeDisplay.mq4 |
//|                       Visual tool to test lot size calculation   |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property strict

extern double RiskPercent = 2.0;            // Risk % of account balance
extern double ATRMultiplier = 1.5;          // SL distance in ATR
extern int    ATRPeriod = 14;               // ATR Period for stoploss
extern int    RefreshRate = 10;             // Refresh every N ticks

int tickCounter = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   // Delete old labels if they exist
   for(int i = 0; i < 4; i++) ObjectDelete("LotSizeText" + i);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int i = 0; i < 4; i++) ObjectDelete("LotSizeText" + i);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   tickCounter++;
   if(tickCounter < RefreshRate)
      return;
   tickCounter = 0;

   double atr = iATR(Symbol(), 0, ATRPeriod, 0);
   double slPips = atr * ATRMultiplier / (Point * 10); // Corrected to reflect true pip size
   double slPriceDistance = slPips * Point * 10;
   double riskAmount = AccountBalance() * RiskPercent / 100.0;

   double contractSize = MarketInfo(Symbol(), MODE_LOTSIZE); // Corrected identifier
   double lotSize = (riskAmount / slPriceDistance) / contractSize;

   // Round down to broker minimum lot step
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   if(lotSize < minLot) lotSize = minLot;

   string lines[4];
   lines[0] = StringFormat("ATR: %.5f", atr);
   lines[1] = StringFormat("SL (%.1fx ATR): %.1f pips", ATRMultiplier, slPips);
   lines[2] = StringFormat("Risk: %.2f%% of %.2f = %.2f", RiskPercent, AccountBalance(), riskAmount);
   lines[3] = StringFormat("Lot Size: %.2f", lotSize);

   for(int i = 0; i < ArraySize(lines); i++)
     {
      DrawText("LotSizeText" + i, lines[i], 10, 10 + i * 18, clrAqua);
     }
  }

//+------------------------------------------------------------------+
void DrawText(string name, string text, int x, int y, color clr)
  {
   ObjectDelete(name); // Force update by removing old label
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }
