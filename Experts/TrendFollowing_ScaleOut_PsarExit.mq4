//+------------------------------------------------------------------+
//| TrendFollowingATR_EA.mq4                                         |
//| 4H/Daily SMA Trend + ADX Filter + ATR SL + Scaling Out + Breakeven|
//| Entry Trigger: Price cross of 50 SMA within trend and ADX filter  |
//| Scales out portion of position at ATRMultiplierTP * ATR          |
//+------------------------------------------------------------------+
#property copyright "2025"
#property link      "https://www.mql5.com/en/users/YourName"
#property version   "1.04"
#property strict
#property show_inputs

//--- Strategy inputs
extern ENUM_TIMEFRAMES   Timeframe              = PERIOD_H4;
extern int               SMAPeriodFast          = 50;
extern int               SMAPeriodSlow          = 200;
extern int               ADXPeriod              = 14;
extern double            ADXThreshold           = 25.0;
extern int               ATRPeriod              = 14;
extern double            ATRMultiplierSL        = 1.5;    // ATR-based stop
extern double            ATRMultiplierTP        = 3.0;    // ATR threshold to scale out
extern double            ScaleOutPercent        = 50.0;   // Percent of lots to scale out
extern double            RiskPercent            = 1.0;
extern double            MaxDailyDDPercent      = 2.0;
extern int               TradingStartHour       = 7;
extern int               TradingEndHour         = 17;
extern int               MinBarsInTrade         = 1;       // Minimum bars before exit
extern double            PSARStep               = 0.02;   // PSAR step for exit
extern double            PSARMax                = 0.2;    // PSAR maximum for exit

//--- Globals
double initialDailyEquity;
datetime lastEquityUpdate;
bool   scaledOut = false;

//--- Scale-out remainder option
extern bool           CloseRemainderOnScale = false;  // Close remaining lots on scale-out

//+------------------------------------------------------------------+
//| Converts a boolean to string                                    |
//+------------------------------------------------------------------+
string BoolToStr(bool value)
  { return(value ? "true" : "false"); }

//+------------------------------------------------------------------+
int OnInit()
  {
   initialDailyEquity = AccountEquity();
   lastEquityUpdate   = TimeCurrent();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  { }

//+------------------------------------------------------------------+
void OnTick()
  {
   // Timeframe filter
   if(Period() != Timeframe) return;

   // Daily equity reset
   datetime currDay = PeriodSeconds(PERIOD_D1) * (TimeCurrent() / PeriodSeconds(PERIOD_D1));
   if(currDay > lastEquityUpdate)
     {
      initialDailyEquity = AccountEquity();
      lastEquityUpdate   = currDay;
     }
   // Daily drawdown
   double dd = (initialDailyEquity - AccountEquity())/initialDailyEquity*100.0;
   if(dd >= MaxDailyDDPercent) return;
   // Time window
   int h = Hour(); if(h < TradingStartHour || h >= TradingEndHour) return;

   // Manage open
   if(OrdersTotal() > 0)
     { ManageOpenOrder(); return; }

   // Indicators
   double maFast = iMA(NULL,Timeframe,SMAPeriodFast,0,MODE_SMA,PRICE_CLOSE,0);
   double maSlow = iMA(NULL,Timeframe,SMAPeriodSlow,0,MODE_SMA,PRICE_CLOSE,0);
   double adx    = iADX(NULL,Timeframe,ADXPeriod,PRICE_CLOSE,MODE_MAIN,0);
   double atr    = iATR(NULL,Timeframe,ATRPeriod,0);
   double close0 = iClose(NULL,Timeframe,0);
   double close1 = iClose(NULL,Timeframe,1);

   bool isBullTrend = maFast > maSlow;
   bool isBearTrend = maFast < maSlow;
   bool momentumOK  = adx > ADXThreshold;

   // Entry conditions
   double prevSMA = iMA(NULL,Timeframe,SMAPeriodFast,0,MODE_SMA,PRICE_CLOSE,1);
   bool crossUp   = isBullTrend && close1 <= prevSMA && close0 > maFast;
   bool crossDown = isBearTrend && close1 >= prevSMA && close0 < maFast;

   // Debug entry
   if(momentumOK)
     PrintFormat("[%s] Check: Bull=%s,Bear=%s,ADX=%s,CrossUp=%s,CrossDown=%s",TimeToString(Time[0],TIME_MINUTES),
       BoolToStr(isBullTrend),BoolToStr(isBearTrend),BoolToStr(momentumOK),
       BoolToStr(crossUp),BoolToStr(crossDown));

   if(momentumOK && crossUp)      SendOrder(OP_BUY,atr);
   else if(momentumOK && crossDown) SendOrder(OP_SELL,atr);
  }

//+------------------------------------------------------------------+
double CalculateLotSize(double slPrice)
  {
   double riskAmount   = AccountBalance()*RiskPercent/100.0;
   double midPrice     = (Ask+Bid)/2.0;
   double dist         = MathAbs(midPrice-slPrice);
   double contractSize = MarketInfo(Symbol(),MODE_LOTSIZE);
   double rawLots      = riskAmount/(dist*contractSize);
   double step         = MarketInfo(Symbol(),MODE_LOTSTEP);
   double minLot       = MarketInfo(Symbol(),MODE_MINLOT);
   double lots         = NormalizeDouble(MathFloor(rawLots/step)*step,2);
   if(lots<minLot) lots=minLot;
   return lots;
  }

//+------------------------------------------------------------------+
void SendOrder(int type,double atr)
  {
   string dir    = type==OP_BUY?"BUY":"SELL";
   double price  = type==OP_BUY?Ask:Bid;
   double sl     = type==OP_BUY?price-ATRMultiplierSL*atr:price+ATRMultiplierSL*atr;
   int    ticket = OrderSend(Symbol(),type,CalculateLotSize(sl),price,3,sl,0,"TrendATR "+dir,0,0,(type==OP_BUY?clrGreen:clrRed));
   if(ticket<0) { Print("SendOrder failed: ",GetLastError()); return; }
   scaledOut = false; Print(dir+" ENTRY at "+DoubleToStr(price,Digits));
  }

//+------------------------------------------------------------------+
void ManageOpenOrder()
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol()) continue;
      int    type       = OrderType();
      double atr        = iATR(NULL,Timeframe,ATRPeriod,0);
      double entryPrice = OrderOpenPrice();
      datetime ot       = OrderOpenTime();
      double current    = type==OP_BUY?Bid:Ask;
      double profitPips = (type==OP_BUY?(current-entryPrice):(entryPrice-current))/Point;

      // scale-out
      double scalePrice = type==OP_BUY?entryPrice+ATRMultiplierTP*atr:entryPrice-ATRMultiplierTP*atr;
      if(!scaledOut && ((type==OP_BUY && current>=scalePrice) || (type==OP_SELL && current<=scalePrice)))
        {
         double closeLots = OrderLots()*ScaleOutPercent/100.0;
         if(closeLots>0)
           {
            OrderClose(OrderTicket(),closeLots,current,3,clrBlue);
            scaledOut = true;
            Print("Scaled out " + DoubleToStr(closeLots,2) + " lots at " + DoubleToStr(current,Digits));
           }
        }
      // breakeven
      if(!scaledOut && profitPips>=ATRMultiplierSL*atr/Point)
        {
         OrderModify(OrderTicket(),entryPrice,entryPrice,0,0,clrYellow);
         Print("Move SL to breakeven at " + DoubleToStr(entryPrice,Digits));
        }
      // min bars
      if(TimeCurrent()-ot<MinBarsInTrade*PeriodSeconds(Timeframe)) continue;
      // exit on SMA cross
      double lastC = iClose(NULL,Timeframe,1);
      double lastS = iMA(NULL,Timeframe,SMAPeriodFast,0,MODE_SMA,PRICE_CLOSE,1);
      bool   exitC = (type==OP_BUY&&lastC<lastS)||(type==OP_SELL&&lastC>lastS);
      if(exitC)
        {
         OrderClose(OrderTicket(),OrderLots(),current,3,clrRed);
         Print("Trend reversal exit at " + DoubleToStr(current,Digits));
        }
      // PSAR-based exit for remainder
      double sar = iSAR(NULL,Timeframe,PSARStep,PSARMax,0);
      bool psarExit = (type==OP_BUY && sar>current) || (type==OP_SELL && sar<current);
      if(psarExit)
        {
         OrderClose(OrderTicket(),OrderLots(),current,3,clrMagenta);
         Print("PSAR exit at " + DoubleToStr(current,Digits));
        }
     }
  }

//+------------------------------------------------------------------+
