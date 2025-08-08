//+------------------------------------------------------------------+
//|                  StableZigZag Indicator                          |
//|        EA-friendly ZigZag matching MT4 ZigZag behavior          |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1 clrRed

input int Depth = 12;              // Number of bars to confirm a pivot (MT4 default)
input double Deviation = 5;        // Minimum price movement in pips (MT4 default)
input int Backstep = 3;            // Bars to look back for stronger pivots (MT4 default)
input bool DebugLog = false;       // Enable debug logging to Experts tab

double ZigZagBuffer[];

int OnInit()
{
   SetIndexStyle(0, DRAW_NONE); // Disable buffer drawing, we'll draw manually
   SetIndexBuffer(0, ZigZagBuffer);
   SetIndexEmptyValue(0, 0.0);
   ArrayInitialize(ZigZagBuffer, 0.0);
   IndicatorShortName("StableZigZag (Depth=" + IntegerToString(Depth) + ", Dev=" + DoubleToString(Deviation, 1) + ")");
   if (DebugLog) Print("StableZigZag initialized");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   // Clean up all ZigZag lines
   for (int i = 0; i < 1000; i++) {
      string objName = "ZigZagLine_" + IntegerToString(i);
      ObjectDelete(objName);
   }
   ArrayInitialize(ZigZagBuffer, 0.0);
}

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
    ArraySetAsSeries(ZigZagBuffer, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(time, true);

    double pipAdjust = (Digits == 3 || Digits == 5) ? 10 : 1;
    double deviation = Deviation * Point * pipAdjust;

    int start = prev_calculated == 0 ? rates_total - Depth - 1 : rates_total - Depth - 1;
    if (start < Depth) start = Depth;
    if (start > rates_total - 1) start = rates_total - 1;

    // Clear buffer for recalculation
    for (int i = start; i >= 0; i--)
    {
        ZigZagBuffer[i] = 0.0;
    }

    // Clear existing ZigZag lines
    for (int i = 0; i < 1000; i++) {
        string objName = "ZigZagLine_" + IntegerToString(i);
        ObjectDelete(objName);
    }

    int lastHighIndex = -1;
    int lastLowIndex = -1;

    // Store pivots for drawing
    struct Pivot { datetime time; double price; };
    Pivot pivots[100];
    int pivotCount = 0;

    for (int i = start; i >= 0; i--)
    {
        // Check for high pivot
        bool isHigh = true;
        for (int j = 1; j <= Depth && i + j < rates_total && i - j >= 0; j++)
        {
            if (high[i] <= high[i + j] || high[i] <= high[i - j])
            {
                isHigh = false;
                break;
            }
        }

        // Check for low pivot
        bool isLow = true;
        for (int j = 1; j <= Depth && i + j < rates_total && i - j >= 0; j++)
        {
            if (low[i] >= low[i + j] || low[i] > low[i - j])
            {
                isLow = false;
                break;
            }
        }

        if (isHigh || isLow)
        {
            double newPivot = isHigh ? high[i] : low[i];
            bool setPivot = false;

            if (lastHighIndex == -1 && lastLowIndex == -1) // First pivot
            {
                setPivot = true;
                if (DebugLog) Print("First pivot at bar ", i, " (", TimeToString(time[i]), "): ", newPivot, " (", isHigh ? "High" : "Low", ")");
            }
            else if (isHigh)
            {
                if (lastLowIndex != -1 && MathAbs(newPivot - ZigZagBuffer[lastLowIndex]) >= deviation)
                {
                    setPivot = true;
                    if (DebugLog) Print("High after low at bar ", i, " (", TimeToString(time[i]), "): ", newPivot);
                }
                else if (lastHighIndex != -1 && i + Backstep >= lastHighIndex && newPivot > ZigZagBuffer[lastHighIndex])
                {
                    setPivot = true;
                    ZigZagBuffer[lastHighIndex] = 0.0;
                    if (DebugLog) Print("Cleared previous high at bar ", lastHighIndex, " (", TimeToString(time[lastHighIndex]), "): ", high[lastHighIndex]);
                }
            }
            else if (isLow)
            {
                if (lastHighIndex != -1 && MathAbs(newPivot - ZigZagBuffer[lastHighIndex]) >= deviation)
                {
                    setPivot = true;
                    if (DebugLog) Print("Low after high at bar ", i, " (", TimeToString(time[i]), "): ", newPivot);
                }
                else if (lastLowIndex != -1 && i + Backstep >= lastLowIndex && newPivot < ZigZagBuffer[lastLowIndex])
                {
                    setPivot = true;
                    ZigZagBuffer[lastLowIndex] = 0.0;
                    if (DebugLog) Print("Cleared previous low at bar ", lastLowIndex, " (", TimeToString(time[lastLowIndex]), "): ", low[lastLowIndex]);
                }
            }

            if (setPivot)
            {
                // Apply Backstep: Look forward to clear weaker pivots of the same type
                for (int back = 1; back <= Backstep && i + back <= rates_total - 1; back++)
                {
                    int forwardIndex = i + back;
                    if (ZigZagBuffer[forwardIndex] != 0.0)
                    {
                        bool forwardIsHigh = ZigZagBuffer[forwardIndex] == high[forwardIndex];
                        if (isHigh && forwardIsHigh && newPivot > ZigZagBuffer[forwardIndex])
                        {
                            if (DebugLog) Print("Cleared weaker high at bar ", forwardIndex, " (", TimeToString(time[forwardIndex]), "): ", ZigZagBuffer[forwardIndex]);
                            ZigZagBuffer[forwardIndex] = 0.0;
                            if (forwardIndex == lastHighIndex) lastHighIndex = -1;
                        }
                        else if (isLow && !forwardIsHigh && newPivot < ZigZagBuffer[forwardIndex])
                        {
                            if (DebugLog) Print("Cleared weaker low at bar ", forwardIndex, " (", TimeToString(time[forwardIndex]), "): ", ZigZagBuffer[forwardIndex]);
                            ZigZagBuffer[forwardIndex] = 0.0;
                            if (forwardIndex == lastLowIndex) lastLowIndex = -1;
                        }
                    }
                }

                ZigZagBuffer[i] = newPivot;

                // Store the pivot for drawing
                pivots[pivotCount].time = time[i];
                pivots[pivotCount].price = newPivot;
                pivotCount++;

                if (DebugLog) Print("ZigZagBuffer[", i, "] = ", newPivot);
                if (isHigh)
                {
                    lastHighIndex = i;
                }
                else
                {
                    lastLowIndex = i;
                }
                if (DebugLog) Print("Set pivot at bar ", i, " (", TimeToString(time[i]), "): ", newPivot, " (", isHigh ? "High" : "Low", ")");
            }
        }
    }

    // Sort pivots by time (ascending) to ensure correct drawing order
    for (int i = 0; i < pivotCount - 1; i++) {
        for (int j = i + 1; j < pivotCount; j++) {
            if (pivots[i].time > pivots[j].time) {
                // Swap
                datetime tempTime = pivots[i].time;
                double tempPrice = pivots[i].price;
                pivots[i].time = pivots[j].time;
                pivots[i].price = pivots[j].price;
                pivots[j].time = tempTime;
                pivots[j].price = tempPrice;
            }
        }
    }

    // Draw ZigZag lines by connecting consecutive pivots
    for (int i = 0; i < pivotCount - 1; i++) {
        string objName = "ZigZagLine_" + IntegerToString(i);
        if (ObjectCreate(0, objName, OBJ_TREND, 0, pivots[i].time, pivots[i].price, pivots[i + 1].time, pivots[i + 1].price)) {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            if (DebugLog) Print("Drew ZigZag line from ", TimeToString(pivots[i].time), " (", pivots[i].price, ") to ", TimeToString(pivots[i + 1].time), " (", pivots[i + 1].price, ")");
        } else {
            if (DebugLog) Print("Failed to draw ZigZag line from ", TimeToString(pivots[i].time), " (", pivots[i].price, ") to ", TimeToString(pivots[i + 1].time), " (", pivots[i + 1].price, ") - Error: ", GetLastError());
        }
    }

    return rates_total;
}