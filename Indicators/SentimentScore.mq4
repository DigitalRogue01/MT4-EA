//+------------------------------------------------------------------+
//|                                            SentimentScore.mq4    |
//|                       Custom MT4 Indicator (by ChatGPT)          |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property strict

//--- input parameters
input int SentimentLookback = 20;
input bool UseMomentumWeight = true;
input color BullishColor = clrLime;
input color BearishColor = clrRed;
input color NeutralColor = clrSilver;
// Removed ENUM_CORNER to avoid type error in MT4 (not available by default)
//input ENUM_CORNER DisplayCorner = CORNER_LEFT_UPPER;

//--- globals
double sentimentScore = 50;
string sentimentLabel = "Neutral";
int bullishCount = 0;
int bearishCount = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorShortName("Sentiment Score (" + SentimentLookback + ")");
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
   if (rates_total < SentimentLookback + 1)
      return(prev_calculated);

   // Reset counters
   double scoreSum = 0;
   bullishCount = 0;
   bearishCount = 0;

   for (int i = 1; i <= SentimentLookback; i++)
   {
      double body = close[i] - open[i];
      double weight = UseMomentumWeight ? MathAbs(body) : 1.0;

      if (body > 0)
      {
         bullishCount++;
         scoreSum += weight;
      }
      else if (body < 0)
      {
         bearishCount++;
         scoreSum -= weight;
      }
   }

   // Normalize sentiment to 0-100 scale
   int maxCount = SentimentLookback * (UseMomentumWeight ? 2 : 1);
   sentimentScore = NormalizeDouble(50 + (scoreSum / maxCount * 100), 2);

   if (sentimentScore > 55) sentimentLabel = "Bullish";
   else if (sentimentScore < 45) sentimentLabel = "Bearish";
   else sentimentLabel = "Neutral";

   // Draw sentiment on chart
   string label = "SentimentLabel";
   string text = "Sentiment: " + sentimentLabel + "\nScore: " + DoubleToString(sentimentScore, 2) +
                 "\nBullish: " + IntegerToString(bullishCount) +
                 "  Bearish: " + IntegerToString(bearishCount) +
                 "\nLookback: " + IntegerToString(SentimentLookback);

   color c = (sentimentScore > 55) ? BullishColor : (sentimentScore < 45) ? BearishColor : NeutralColor;

   Comment(text);

   return(rates_total);
}

//+------------------------------------------------------------------+
