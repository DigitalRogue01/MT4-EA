//+------------------------------------------------------------------+
//| TrendFollowingATR_EA.mq4                                         |
//| 4H/Daily SMA Trend + ADX Filter + ATR SL/TP + Breakeven          |
//| Entry Trigger: Price cross of 50 SMA within trend and ADX filter  |
//| Added debug logs for entry signals to identify missed trades      |
//+------------------------------------------------------------------+
#property copyright "2025"
#property link      "https://www.mql5.com/en/users/YourName"
#property version   "1.03"
#property strict
#property show_inputs

//--- Strategy inputs
extern ENUM_TIMEFRAMES   Timeframe              = PERIOD_H4;
extern int               SMAPeriodFast          = 50;
extern int               SMAPeriodSlow          = 200;
extern int               ADXPeriod              = 14;
extern double            ADXThreshold           = 25.0;
extern int               ATRPeriod              = 14;
extern double            ATRMultiplierSL        = 1.5;
extern double            ATRMultiplierTP        = 3.0;
extern double            RiskPercent            = 1.0;
extern double            MaxDailyDDPercent      = 2.0;
extern int               TradingStartHour       = 7;
extern int               TradingEndHour         = 17;
extern int               MinBarsInTrade         = 1;

//--- Globals
double initialDailyEquity;
datetime lastEquityUpdate;

//+------------------------------------------------------------------+
//| Converts a boolean to string                                    |
//+------------------------------------------------------------------+
string BoolToStr(bool value)
  {
   return(value ? "true" : "false");
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   initialDailyEquity = AccountEquity();
   lastEquityUpdate   = TimeCurrent();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(Period() != Timeframe) return;

   // Reset daily equity at new day
   datetime currDay = PeriodSeconds(PERIOD_D1) * (TimeCurrent() / PeriodSeconds(PERIOD_D1));
   if(currDay > lastEquityUpdate)
     {
      initialDailyEquity = AccountEquity();
      lastEquityUpdate   = currDay;
     }

   // Daily drawdown filter
   double dd = (initialDailyEquity - AccountEquity()) / initialDailyEquity * 100.0;
   if(dd >= MaxDailyDDPercent) return;

   // Time window filter
   int h = Hour();
   if(h < TradingStartHour || h >= TradingEndHour) return;

   // Manage open orders
   if(OrdersTotal() > 0)
     {
      ManageOpenOrder();
      return;
     }

   // Fetch indicators
   double maFast = iMA(NULL,Timeframe,SMAPeriodFast,0,MODE_SMA,PRICE_CLOSE,0);
   double maSlow = iMA(NULL,Timeframe,SMAPeriodSlow,0,MODE_SMA,PRICE_CLOSE,0);
   double adx    = iADX(NULL,Timeframe,ADXPeriod,PRICE_CLOSE,MODE_MAIN,0);
   double atr    = iATR(NULL,Timeframe,ATRPeriod,0);
   double close0 = iClose(NULL,Timeframe,0);
   double close1 = iClose(NULL,Timeframe,1);

   bool isBullTrend = (maFast > maSlow);
   bool isBearTrend = (maFast < maSlow);
   bool momentumOK  = (adx > ADXThreshold);

   // Debug log entry conditions
   double prevSMA = iMA(NULL,Timeframe,SMAPeriodFast,0,MODE_SMA,PRICE_CLOSE,1);
   bool crossUp   = isBullTrend && close1 <= prevSMA && close0 > maFast;
   bool crossDown = isBearTrend && close1 >= prevSMA && close0 < maFast;

   if(momentumOK)
     {
      PrintFormat("[%s] EntryCheck: Bull=%s, Bear=%s, ADXok=%s, Prev<=SMA=%s, Prev>=SMA=%s, Curr>Fast=%s, Curr<Fast=%s", 
         TimeToString(Time[0],TIME_DATE|TIME_MINUTES),
         BoolToStr(isBullTrend), BoolToStr(isBearTrend), BoolToStr(momentumOK),
         BoolToStr(close1 <= prevSMA), BoolToStr(close1 >= prevSMA),
         BoolToStr(close0 > maFast), BoolToStr(close0 < maFast));
     }

   // Entry signals
   if(crossUp)      SendOrder(OP_BUY,atr);
   else if(crossDown) SendOrder(OP_SELL,atr);
  }

//+------------------------------------------------------------------+
double CalculateLotSize(double slPrice)
  {
   double riskAmount   = AccountBalance() * RiskPercent / 100.0;
   double midPrice     = (Ask + Bid) / 2.0;
   double slDistance   = MathAbs(midPrice - slPrice);
   double contractSize = MarketInfo(Symbol(), MODE_LOTSIZE);
   double rawLots      = riskAmount / (slDistance * contractSize);
   double lotStep      = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot       = MarketInfo(Symbol(), MODE_MINLOT);
   double lots         = NormalizeDouble(MathFloor(rawLots / lotStep) * lotStep, 2);
   if(lots < minLot) lots = minLot;
   return(lots);
  }

//+------------------------------------------------------------------+
void SendOrder(int type,double atr)
  {
   string dir    = type == OP_BUY ? "BUY" : "SELL";
   double price  = type == OP_BUY ? Ask : Bid;
   double sl     = type == OP_BUY ? price - ATRMultiplierSL * atr : price + ATRMultiplierSL * atr;
   double tp     = type == OP_BUY ? price + ATRMultiplierTP * atr : price - ATRMultiplierTP * atr;
   double lot    = CalculateLotSize(sl);
   color  clr    = type == OP_BUY ? clrGreen : clrRed;
   PrintFormat("%s SIGNAL -> lot=%.2f price=%s SL=%s TP=%s", dir, lot,
               DoubleToStr(price, Digits), DoubleToStr(sl, Digits), DoubleToStr(tp, Digits));
   int ticket = OrderSend(Symbol(), type, lot, price, 3, sl, tp, "TrendATR " + dir, 0, 0, clr);
   if(ticket < 0) Print("OrderSend failed: ", GetLastError());
  }

//+------------------------------------------------------------------+
void ManageOpenOrder()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      int    type       = OrderType();
      double atr        = iATR(NULL, Timeframe, ATRPeriod, 0);
      double entryPrice = OrderOpenPrice();
      datetime ot       = OrderOpenTime();
      double current    = type == OP_BUY ? Bid : Ask;
      double profitPips = (type == OP_BUY ? current - entryPrice : entryPrice - current) / Point;

      // Move SL to breakeven
      if(profitPips >= ATRMultiplierSL * atr / Point)
         OrderModify(OrderTicket(), entryPrice, entryPrice, OrderTakeProfit(), 0, clrYellow);

      // Minimum bars in trade
      if(TimeCurrent() - ot < MinBarsInTrade * PeriodSeconds(Timeframe)) continue;

      // Exit on trend reversal
      double lastClose = iClose(NULL, Timeframe, 1);
      double lastSMA   = iMA(NULL, Timeframe, SMAPeriodFast, 0, MODE_SMA, PRICE_CLOSE, 1);
      bool exitCond    = (type == OP_BUY && lastClose < lastSMA) ||
                         (type == OP_SELL && lastClose > lastSMA);
      if(exitCond)
         OrderClose(OrderTicket(), OrderLots(), current, 3, clrRed);
     }
  }

//+------------------------------------------------------------------+
