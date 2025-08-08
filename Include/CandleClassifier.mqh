//+------------------------------------------------------------------+
//|              CandleClassifier.mqh                                |
//|   Identifies basic candle types (for training/visual insight)   |
//+------------------------------------------------------------------+
#ifndef __CANDLE_CLASSIFIER_MQH__
#define __CANDLE_CLASSIFIER_MQH__

string ClassifyCandle(int shift)
{
   double open  = iOpen(Symbol(), 0, shift);
   double close = iClose(Symbol(), 0, shift);
   double high  = iHigh(Symbol(), 0, shift);
   double low   = iLow(Symbol(), 0, shift);

   double body      = MathAbs(close - open);
   double range     = high - low;
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;

   if (range == 0) return "Flat Candle";

   double bodyPercent = body / range;
   double upperPercent = upperWick / range;
   double lowerPercent = lowerWick / range;

   if (bodyPercent < 0.1)
   {
      if (upperPercent > 0.4 && lowerPercent > 0.4)
         return "Doji";
      if (upperPercent > 0.6)
         return "Gravestone Doji";
      if (lowerPercent > 0.6)
         return "Dragonfly Doji";
   }
   else if (bodyPercent > 0.7)
   {
      if (upperPercent < 0.1 && lowerPercent < 0.1)
         return (close > open) ? "Bullish Marubozu" : "Bearish Marubozu";
   }
   else
   {
      if (lowerPercent > 0.6 && upperPercent < 0.2)
         return (close > open) ? "Hammer" : "Hanging Man";
      if (upperPercent > 0.6 && lowerPercent < 0.2)
         return (close > open) ? "Inverted Hammer" : "Shooting Star";
      if (upperPercent > 0.2 && lowerPercent > 0.2)
         return "Spinning Top";
   }

   return (close > open) ? "Bullish Candle" : "Bearish Candle";
}



//+------------------------------------------------------------------+
//| Two-Candle Pattern Classification                               |
//+------------------------------------------------------------------+
string ClassifyTwoCandlePattern(int shift)
{
   double open1 = iOpen(Symbol(), 0, shift);
   double close1 = iClose(Symbol(), 0, shift);
   double open2 = iOpen(Symbol(), 0, shift - 1);
   double close2 = iClose(Symbol(), 0, shift - 1);

   bool bullish1 = close1 > open1;
   bool bearish1 = close1 < open1;
   bool bullish2 = close2 > open2;
   bool bearish2 = close2 < open2;

   // Bullish Engulfing
   if (bearish2 && bullish1 && close1 > open2 && open1 < close2)
      return "Bullish Engulfing";

   // Bearish Engulfing
   if (bullish2 && bearish1 && close1 < open2 && open1 > close2)
      return "Bearish Engulfing";

   // Tweezer Bottom
   if (bearish2 && bullish1 && MathAbs(open2 - open1) < Point*5)
      return "Tweezer Bottom";

   // Tweezer Top
   if (bullish2 && bearish1 && MathAbs(open2 - open1) < Point*5)
      return "Tweezer Top";

   // Harami
   if ((bullish2 && bearish1 && open1 > open2 && close1 < close2) ||
       (bearish2 && bullish1 && open1 < open2 && close1 > close2))
      return "Harami";

   return "No 2-Candle Pattern";
}

//+------------------------------------------------------------------+
//| Three-Candle Pattern Classification                             |
//+------------------------------------------------------------------+
string ClassifyThreeCandlePattern(int shift)
{
   double o1 = iOpen(Symbol(), 0, shift);
   double c1 = iClose(Symbol(), 0, shift);
   double o2 = iOpen(Symbol(), 0, shift - 1);
   double c2 = iClose(Symbol(), 0, shift - 1);
   double o3 = iOpen(Symbol(), 0, shift - 2);
   double c3 = iClose(Symbol(), 0, shift - 2);

   // Morning Star
   if (c3 < o3 && MathAbs(c2 - o2) < (iHigh(Symbol(), 0, shift - 1) - iLow(Symbol(), 0, shift - 1)) * 0.3 && c1 > o1 && c1 > ((o3 + c3) / 2))
      return "Morning Star";

   // Evening Star
   if (c3 > o3 && MathAbs(c2 - o2) < (iHigh(Symbol(), 0, shift - 1) - iLow(Symbol(), 0, shift - 1)) * 0.3 && c1 < o1 && c1 < ((o3 + c3) / 2))
      return "Evening Star";

   // Three White Soldiers
   if (c3 < o3 && c2 > o2 && c1 > o1 && c3 < c2 && c2 < c1)
      return "Three White Soldiers";

   // Three Black Crows
   if (c3 > o3 && c2 < o2 && c1 < o1 && c3 > c2 && c2 > c1)
      return "Three Black Crows";

   return "No 3-Candle Pattern";
}

#endif // __CANDLE_CLASSIFIER_MQH__
