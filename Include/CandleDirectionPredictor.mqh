//+------------------------------------------------------------------+
//|        CandleDirectionPredictor.mqh (v1)                         |
//|  Predicts next candle direction using shape + PSAR + scoring     |
//+------------------------------------------------------------------+
#ifndef __CANDLE_DIRECTION_PREDICTOR_MQH__
#define __CANDLE_DIRECTION_PREDICTOR_MQH__

enum PredictionDirection { PREDICT_BUY, PREDICT_SELL, PREDICT_NEUTRAL };

int correctGuesses = 0;
int wrongGuesses = 0;
PredictionDirection lastPrediction = PREDICT_NEUTRAL;
bool predictionActive = false;
double predictionEntryPrice = 0.0;
double predictionExitPrice = 0.0;
extern double predictionLots;
double simulatedPL = 0.0;

//+------------------------------------------------------------------+
//| Predict direction using last candle + PSAR                       |
//+------------------------------------------------------------------+
PredictionDirection PredictNextCandleDirection()
{
   int shift = 1;
   double open = iOpen(Symbol(), 0, shift);
   double close = iClose(Symbol(), 0, shift);
   double high = iHigh(Symbol(), 0, shift);
   double low = iLow(Symbol(), 0, shift);
   double body = MathAbs(close - open);
   double wickTop = high - MathMax(open, close);
   double wickBottom = MathMin(open, close) - low;
   double psar = iSAR(Symbol(), 0, 0.02, 0.2, shift);

   bool isBullish = close > open;
   bool psarBelow = psar < low;
   bool psarAbove = psar > high;

   if (body < (wickTop + wickBottom) * 0.5)
      return PREDICT_NEUTRAL; // small or indecisive candle

   if (isBullish && psarBelow)
      return PREDICT_BUY;

   if (!isBullish && psarAbove)
      return PREDICT_SELL;

   return PREDICT_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Handle scoring based on candle that just closed (Candle[0])     |
//+------------------------------------------------------------------+
void ScoreLastPrediction()
{
   if (!predictionActive) return;
   predictionExitPrice = iClose(Symbol(), 0, 1);

   bool correct = false;
   if (lastPrediction == PREDICT_BUY && predictionExitPrice > predictionEntryPrice)
      correct = true;
   else if (lastPrediction == PREDICT_SELL && predictionExitPrice < predictionEntryPrice)
      correct = true;

   if (correct) correctGuesses++;
   else wrongGuesses++;

   predictionActive = false;
}

//+------------------------------------------------------------------+
//| Display all diagnostics on chart                                 |
//+------------------------------------------------------------------+
void ShowCandlePredictionDiagnostics(bool multiline = True)
{
   // Build full multiline version
   string dirText = "Prediction: ";
   color textColor = White;
   switch (lastPrediction)
   {
      case PREDICT_BUY: dirText += "BUY"; textColor = Lime; break;
      case PREDICT_SELL: dirText += "SELL"; textColor = Red; break;
      case PREDICT_NEUTRAL: dirText += "NEUTRAL"; textColor = Silver; break;
   }

   double balance = AccountBalance();
   double accuracy = (correctGuesses + wrongGuesses > 0)
                     ? 100.0 * correctGuesses / (correctGuesses + wrongGuesses)
                     : 0.0;

   double pipResult = (predictionExitPrice - predictionEntryPrice) *
                      (lastPrediction == PREDICT_BUY ? 10000 : -10000);

   string panel = (multiline)
       ? StringFormat(
           "%s\nEntry: %.5f\nExit: %.5f\nResult: %.1f pips\nSimPL: $%.2f\nLots: %.2f\nScore: %d/%d (%.1f%%)\nBalance: $%.2f",
           dirText,
           predictionEntryPrice,
           predictionExitPrice,
           pipResult,
           simulatedPL,
           predictionLots,
           correctGuesses, wrongGuesses, accuracy,
           balance)
       : StringFormat(
           "%s Entry: %.5f Exit: %.5f Result: %.1f pips",
           dirText,
           predictionEntryPrice,
           predictionExitPrice,
           pipResult
       );

Print("PANEL TEXT:\n", panel);
         string objName = "PredictionPanel";
         if (!ObjectFind(0, objName))
            ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);

// Always set this:
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 14);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);  // Force white for testing
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
      ObjectSetString(0, objName, OBJPROP_TEXT, panel);

}
