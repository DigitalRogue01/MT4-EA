//+------------------------------------------------------------------+
//|                                         SentimentScore_v2.mq4    |
//|          Updated sentiment indicator with bottom‑right gauge    |
//|                                                                |
//|  This version calculates a sentiment score based on bullish    |
//|  versus bearish candle bodies, with optional momentum and      |
//|  recency weighting. It draws a simple gauge in the lower‑right |
//|  corner of the chart showing the sentiment percentage.         |
//+------------------------------------------------------------------+

#property copyright   "2025"
#property version     "1.2"
#property indicator_chart_window

// Input parameters
extern int  SentimentLookback = 20;     // number of candles to analyze
extern bool UseMomentumWeight  = true;  // weight by candle body size
extern int  OffsetBars        = 20;   // shift gauge left by this many bars

// Global sentiment value
double gSentiment = 50.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Draw initial gauge
   DrawGauge();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Ensure we have enough data
   if(rates_total <= SentimentLookback)
      return 0;

   double bullWeight = 0.0, bearWeight = 0.0;

   // Calculate weights over the lookback period
   for(int i = 0; i < SentimentLookback; i++)
   {
      double body = close[i] - open[i];
      // Filter out very small candles to reduce noise
      if(MathAbs(body) < (Point * 50))
         continue;

      // Newer bars count more than older ones
      double recency  = (SentimentLookback - i) / (double)SentimentLookback;
      // Larger candle bodies count more if enabled
      double magnitude = UseMomentumWeight ? MathAbs(body) : 1.0;
      double weight    = recency * magnitude;

      if(body > 0)
         bullWeight += weight;
      else
         bearWeight += weight;
   }

   double totalWeight = bullWeight + bearWeight;
   if(totalWeight > 0)
      gSentiment = (bullWeight / totalWeight) * 100.0;
   else
      gSentiment = 50.0;

   // Update the gauge with the new sentiment value
   DrawGauge();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Draw or update the sentiment gauge                               |
//+------------------------------------------------------------------+
void DrawGauge()
{
   string base  = "SentimentGauge";
   int    xOff  = 10;   // base distance from right edge
   int    yOff  = 20;   // distance from bottom edge
   int    width = 200;  // gauge width in pixels
   int    height= 12;   // gauge height in pixels
   // Place objects in the lower‑right corner
   int    corner = CORNER_RIGHT_LOWER;

   // Calculate additional pixel offset based on number of bars to shift
   // This allows moving the gauge left by a specific number of bars.
   int computedXOff = xOff;
   // Only apply bar‑based offset if a positive OffsetBars value is provided
   if(OffsetBars > 0)
   {
      // Get the number of visible bars and chart width to estimate pixels per bar
      long visBars   = ChartGetInteger(0, CHART_VISIBLE_BARS, 0);
      long chartW    = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      if(visBars > 0)
      {
         // Approximate pixel width of one bar
         double pixelsPerBar = (double)chartW / (double)visBars;
         computedXOff = xOff + (int)(pixelsPerBar * OffsetBars);
      }
   }

   // Background rectangle
   string bgName = base + "_bg";
   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
      ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrGray);
   }
   ObjectSetInteger(0, bgName, OBJPROP_CORNER,   corner);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, computedXOff);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, yOff);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE,     width);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE,     height);

   // Bearish bar (red) drawn first and fills the entire gauge width
   string bearName = base + "_bear";
   if(ObjectFind(0, bearName) < 0)
   {
      ObjectCreate(0, bearName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bearName, OBJPROP_BACK, true);
   }
   ObjectSetInteger(0, bearName, OBJPROP_CORNER,   corner);
   ObjectSetInteger(0, bearName, OBJPROP_COLOR,    clrRed);
   ObjectSetInteger(0, bearName, OBJPROP_XDISTANCE, computedXOff);
   ObjectSetInteger(0, bearName, OBJPROP_YDISTANCE, yOff);
   ObjectSetInteger(0, bearName, OBJPROP_XSIZE,     width);
   ObjectSetInteger(0, bearName, OBJPROP_YSIZE,     height);

   // Bullish bar (green) overlays the bearish bar; width proportional to sentiment
   string bullName = base + "_bull";
   if(ObjectFind(0, bullName) < 0)
   {
      ObjectCreate(0, bullName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bullName, OBJPROP_BACK, true);
   }
   double bullWidth = (gSentiment / 100.0) * width;
   ObjectSetInteger(0, bullName, OBJPROP_CORNER,   corner);
   ObjectSetInteger(0, bullName, OBJPROP_COLOR,    clrLime);
   ObjectSetInteger(0, bullName, OBJPROP_XDISTANCE, computedXOff);
   ObjectSetInteger(0, bullName, OBJPROP_YDISTANCE, yOff);
   ObjectSetInteger(0, bullName, OBJPROP_XSIZE,     (int)bullWidth);
   ObjectSetInteger(0, bullName, OBJPROP_YSIZE,     height);

   // Text label displaying the sentiment percentage
   string lblName = base + "_text";
   if(ObjectFind(0, lblName) < 0)
   {
      ObjectCreate(0, lblName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, clrWhite);
   }
   ObjectSetInteger(0, lblName, OBJPROP_CORNER,   corner);
   ObjectSetInteger(0, lblName, OBJPROP_XDISTANCE, computedXOff);
   // Position text just below the gauge bar
   ObjectSetInteger(0, lblName, OBJPROP_YDISTANCE, yOff + height + 2);
   string text = "Sentiment: " + DoubleToString(gSentiment, 1) + "%";
   ObjectSetString(0, lblName, OBJPROP_TEXT, text);
}