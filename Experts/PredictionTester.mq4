//+------------------------------------------------------------------+
//|                   PredictionTester.mq4                           |
//|       Uses CandleDirectionPredictor.mqh to test predictions      |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window

#include <LotSize_Calculations.mqh>
#include <CandleDirectionPredictor.mqh>
#include <CandleClassifier.mqh>

input double RiskPercent   = 2.0;   // % risk per trade
input int    ATRPeriod     = 14;    // ATR period for SL
input double ATRMultiplier = 1.0;   // SL = ATR * multiplier

datetime lastBarTime = 0;
bool initialized = false;

//+------------------------------------------------------------------+
int OnInit()
{
   lastBarTime = Time[0];
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete("PredictionPanel");
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Initialize when ready
   if (!initialized)
   {
      if (Bars < 20 || iATR(Symbol(), 0, ATRPeriod, 1) == 0.0)
         return;
      initialized = true;
      Print("PredictionTester initialized after data warm-up.");
   }

   // Delay scoring by 1 tick after new candle
   if (Time[0] != lastBarTime)
   {
      // Only score AFTER the full candle closes (1-tick delay)
      if (predictionActive && predictionEntryPrice > 0.0)
         predictionExitPrice = Close[1];

      if (predictionExitPrice > 0.0 && predictionEntryPrice > 0.0 && predictionActive)
      {
         ScoreLastPrediction();
         predictionActive = false; // mark as scored
      }

      // Reset and make new prediction
      predictionEntryPrice = 0.0;
      predictionExitPrice = 0.0;
      predictionLots = 0.0;

      lastPrediction = PredictNextCandleDirection();
      predictionActive = (lastPrediction != PREDICT_NEUTRAL);

      if (predictionActive)
      {
         predictionEntryPrice = Open[0];
         double slPrice = ATRMultiplier * iATR(Symbol(), 0, ATRPeriod, 0);
         bool isBuy = (lastPrediction == PREDICT_BUY);
         predictionLots = CalculateLotSize(slPrice, isBuy);
      }

      // Classification (once per candle)
      string candleName = ClassifyCandle(1);
      string twoCandleName = ClassifyTwoCandlePattern(2);
      string threeCandleName = ClassifyThreeCandlePattern(3);
      Print("Candle[1] classified as: ", candleName);
      Print("2-Candle Pattern: ", twoCandleName);
      Print("3-Candle Pattern: ", threeCandleName);

      lastBarTime = Time[0];
   }

   // Display status (every tick OK)
   ShowCandlePredictionDiagnostics(true);
}
