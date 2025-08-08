#property strict
#include <stdlib.mqh>

//+------------------------------------------------------------------+
//| Expert Advisor: LiquidityHunter_v7                               |
//| Uses fractal-anchored Fibonacci, Gap-Opposite, Filters,         |
//| Scale-out, Trailing Stop, PSAR Exit, and Logging                  |
//+------------------------------------------------------------------+

//--- Global Variables
int    ticket          = -1;
bool   inTrade         = false;
string inTradeType     = "";
bool   hasScaledOut    = false;
static double atrSum   = 0;
static int    atrCount = 0;

//--- Fibonacci Anchors
int    fibHighBar;
int    fibLowBar;
double fibHigh;
double fibLow;

//--- Log File
string logFileName = "LiquidityHuntingLog.csv";

//--- Input Parameters
input int    FibLookback      = 100;
input double RiskPercent      = 2.0;     // % of balance risk per trade
input int    Slippage         = 3;
input int    ATR_Period       = 14;
input double ATR_StopMult     = 1.5;
input double ATR_ScaleMult    = 1.0;
input double ATR_TrailMult    = 1.0;
input double GapATRMult      = 0.5;
input bool   UseADXFilter     = true;
input int    ADX_Period       = 14;
input double ADX_Threshold    = 20.0;
input bool   EnableReversals  = true;
input bool   UseATRFilter     = true;
input int    ATR_FilterLook   = 14;
input double ATR_FilterMult   = 1.0;
input double PSAR_Step        = 0.06;
input double PSAR_Max         = 0.2;
input double MaxLot           = 50.0;

//+------------------------------------------------------------------+
int OnInit()
{
   // Draw EA start line
   ObjectCreate(0, "EA_Start", OBJ_VLINE, 0, Time[0], 0);
   ObjectSetInteger(0, "EA_Start", OBJPROP_COLOR, clrYellow);
   
   // Initialize log file
   if(!FileIsExist(logFileName))
   {
      int h = FileOpen(logFileName, FILE_CSV|FILE_WRITE, ',');
      if(h != INVALID_HANDLE)
      {
         FileWrite(h, "Time","Symbol","Mode","Direction","Entry","SL","Score","Lots");
         FileClose(h);
      }
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBar = 0;
   if(Time[0] == lastBar) return;  // only once per bar
   lastBar = Time[0];

   // Update and draw Fibonacci levels
   UpdateFibAnchors();
   DrawFibRetracement();

   // Update ATR rolling for filter
   double atrNow = iATR(_Symbol, PERIOD_CURRENT, ATR_Period, 1);
   atrSum += atrNow;
   if(++atrCount > ATR_FilterLook)
   {
      atrSum -= iATR(_Symbol, PERIOD_CURRENT, ATR_Period, ATR_FilterLook);
      atrCount = ATR_FilterLook;
   }
   double atrAvg = atrSum / atrCount;

   // Clean up orphaned trades
   if(inTrade && OrdersTotal() == 0)
   {
      inTrade = false;
      ticket  = -1;
      hasScaledOut = false;
   }

   // PSAR exit
   if(inTrade && CheckPSARExit())
      CloseTrade();

   // Manage existing trade
   if(inTrade)
   {
      // Opposite signal entries
      string dir; double score;
      if(EnableReversals && DetectReversal(dir, score, atrNow, atrAvg) && dir != inTradeType && score >= 3)
      {
         CloseTrade();
         OpenTrade(dir, score, "Reversal", atrNow);
         return;
      }
      if(DetectBreakout(dir, score, atrNow, atrAvg) && dir != inTradeType && score >= 3)
      {
         CloseTrade();
         OpenTrade(dir, score, "Breakout", atrNow);
         return;
      }
      // Scale-out then trailing stop
      if(!hasScaledOut) ScaleOut();
      TrailStop(atrNow);
      return;
   }

   // New trade detection
   // Gap-Opposite signal
   double gap = Open[0] - Close[1];
   if(fabs(gap) > GapATRMult * atrNow)
   {
      string gapDir = gap>0?"Sell":"Buy";
      OpenTrade(gapDir, 3, "Gap", atrNow);
      return;
   }

   // Pattern signals
   string signal; double scr;
   if(EnableReversals && DetectReversal(signal, scr, atrNow, atrAvg))
   {
      if(scr >= 3)
         OpenTrade(signal, scr, "Reversal", atrNow);
      return;
   }
   if(DetectBreakout(signal, scr, atrNow, atrAvg))
   {
      if(scr >= 3)
         OpenTrade(signal, scr, "Breakout", atrNow);
      return;
   }
}

//+------------------------------------------------------------------+
void UpdateFibAnchors()
{
   fibHighBar = -1; fibLowBar = -1;
   for(int i=1; i<=FibLookback; i++)
   {
      if(iFractals(_Symbol, 0, MODE_UPPER, i)>0 && fibHighBar<0) fibHighBar = i;
      if(iFractals(_Symbol, 0, MODE_LOWER, i)>0 && fibLowBar<0) fibLowBar = i;
      if(fibHighBar>0 && fibLowBar>0) break;
   }
   fibHigh = fibHighBar>0? High[fibHighBar] : High[1];
   fibLow  = fibLowBar>0? Low[fibLowBar]   : Low[1];
}

//+------------------------------------------------------------------+
void DrawFibRetracement()
{
   string name = "LH_Fib";
   if(ObjectFind(0,name)==-1)
      ObjectCreate(0,name,OBJ_FIBO,0, Time[fibHighBar], fibHigh, Time[fibLowBar], fibLow);
   else
   {
      ObjectMove(0,name,0,Time[fibHighBar], fibHigh);
      ObjectMove(0,name,1,Time[fibLowBar], fibLow);
   }
   ObjectSetInteger(0,name,OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0,name,OBJPROP_LEVELCOLOR, clrYellow);
   ObjectSetInteger(0,name,OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
bool DetectReversal(string &dir, double &score, double atrNow, double atrAvg)
{
   if(UseATRFilter && atrNow < atrAvg * ATR_FilterMult) return false;
   if(UseADXFilter)
   {
      double adx = iADX(_Symbol, PERIOD_CURRENT, ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
      if(adx >= ADX_Threshold) return false;
   }
   double wLow = Low[1], wHigh = High[1], c1 = Close[1], o1 = Open[1];
   score = 0;
   if(wLow < fibLow && c1 > fibLow && c1 > o1)
   {
      dir = "Buy";
      score = 3 + (Close[2] > fibLow? 1:0);
      return true;
   }
   if(wHigh > fibHigh && c1 < fibHigh && c1 < o1)
   {
      dir = "Sell";
      score = 3 + (Close[2] < fibHigh? 1:0);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool DetectBreakout(string &dir, double &score, double atrNow, double atrAvg)
{
   if(UseATRFilter && atrNow > atrAvg * ATR_FilterMult) {}
   if(UseADXFilter)
   {
      double adx = iADX(_Symbol, PERIOD_CURRENT, ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
      if(adx < ADX_Threshold) return false;
   }
   score = 0;
   double c0 = Close[0], p0 = Close[1];
   if(c0 > fibHigh)
   {
      dir = "Buy";
      score = 3 + (p0 <= fibHigh?1:0);
      return true;
   }
   if(c0 < fibLow)
   {
      dir = "Sell";
      score = 3 + (p0 >= fibLow?1:0);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void OpenTrade(string direction, double score, string mode, double atrNow)
{
   hasScaledOut = false;
   double slDist = atrNow * ATR_StopMult;
   double pip    = MarketInfo(_Symbol, MODE_POINT) * 10;
   double rawLots= (AccountBalance() * RiskPercent/100.0) / (slDist/pip * MarketInfo(_Symbol, MODE_TICKVALUE));
   double minL   = MarketInfo(_Symbol, MODE_MINLOT);
   double step   = MarketInfo(_Symbol, MODE_LOTSTEP);
   double lots   = NormalizeDouble(MathMin(MaxLot, MathMax(minL, MathFloor(rawLots/step)*step)), 2);
   double price  = direction=="Buy"? Ask : Bid;
   double sl     = direction=="Buy"? price - slDist : price + slDist;
   int    cmd    = direction=="Buy"? OP_BUY : OP_SELL;
   color  clr    = direction=="Buy"? clrLime : clrRed;

   ticket = OrderSend(_Symbol, cmd, lots, price, Slippage, sl, 0, "LHv7", 0, clr);
   if(ticket > 0)
   {
      inTrade      = true;
      inTradeType  = direction;
      LogTrade(mode, direction, price, sl, score, lots);
   }
   else
      Print("OrderSend failed #", GetLastError());
}

//+------------------------------------------------------------------+
void ScaleOut()
{
   if(ticket < 0) return;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   double atrNow = iATR(_Symbol, PERIOD_CURRENT, ATR_Period, 1);
   double move = (inTradeType=="Buy"? Bid - OrderOpenPrice() : OrderOpenPrice() - Ask);
   if(move >= ATR_ScaleMult * atrNow)
   {
      double half = OrderLots()/2;
      if(half >= MarketInfo(_Symbol,MODE_MINLOT))
      {
         double price = inTradeType=="Buy"? Bid:Ask;
         if(OrderClose(ticket, half, price, Slippage))
         {
            LogTrade("ScaleOut", inTradeType, price, OrderStopLoss(), 0, half);
            // move SL to breakeven
            OrderModify(ticket, OrderOpenPrice(), OrderOpenPrice(), 0, 0);
            hasScaledOut = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
void TrailStop(double atrNow)
{
   if(ticket < 0) return;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return;
   double slOld = OrderStopLoss();
   double newSL = 0;
   if(OrderType()==OP_BUY)
   {
      newSL = Bid - ATR_TrailMult * atrNow;
      if(newSL > slOld)
         OrderModify(ticket, OrderOpenPrice(), NormalizeDouble(newSL, Digits), 0, 0);
   }
   else
   {
      newSL = Ask + ATR_TrailMult * atrNow;
      if(newSL < slOld)
         OrderModify(ticket, OrderOpenPrice(), NormalizeDouble(newSL, Digits), 0, 0);
   }
}

//+------------------------------------------------------------------+
bool CheckPSARExit()
{
   if(ticket < 0) return false;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   double ps = iSAR(_Symbol, PERIOD_CURRENT, PSAR_Step, PSAR_Max, 0);
   return (OrderType()==OP_BUY && Close[0] < ps) ||
          (OrderType()==OP_SELL && Close[0] > ps);
}

//+------------------------------------------------------------------+
void CloseTrade()
{
   if(ticket < 0) return;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   double price = OrderType()==OP_BUY? Bid:Ask;
   double lots  = OrderLots();
   if(OrderClose(ticket, lots, price, Slippage))
      LogTrade("Exit", inTradeType, price, 0, 0, lots);
   inTrade = false;
   ticket  = -1;
}

//+------------------------------------------------------------------+
void LogTrade(string mode, string dir, double entry, double sl, double score, double lots)
{
   int h = FileOpen(logFileName, FILE_CSV|FILE_READ|FILE_WRITE, ',');
   if(h != INVALID_HANDLE)
   {
      FileSeek(h,0,SEEK_END);
      FileWrite(h,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         _Symbol,
         mode,
         dir,
         NormalizeDouble(entry, Digits),
         NormalizeDouble(sl, Digits),
         score,
         NormalizeDouble(lots, 2)
      );
      FileClose(h);
   }
}

//+------------------------------------------------------------------+
