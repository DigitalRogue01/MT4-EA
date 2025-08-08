//+------------------------------------------------------------------+
//|                  Simple ZigZag Indicator                         |
//|        MetaQuotes-style, Alternating, EA-friendly ZigZag        |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_color1 Red

input int Depth = 12;              // Similar to MetaQuotes ZigZag Depth
input double Deviation = 5;        // Minimum deviation in pips
input int Backstep = 3;            // Bars to look back and clear weaker pivots

double ZigZagBuffer[];

double HighBuffer[];
double LowBuffer[];

int OnInit()
{
   SetIndexStyle(0, DRAW_SECTION);
   SetIndexBuffer(0, ZigZagBuffer);
   SetIndexEmptyValue(0, 0.0);
   ArrayInitialize(ZigZagBuffer, 0.0);
   IndicatorShortName("Simple ZigZag MQ Style");
   return INIT_SUCCEEDED;
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

    double deviation = Deviation * Point;

    int lastHighIndex = -1;
    int lastLowIndex = -1;

    for (int i = rates_total - Depth - 1; i >= 0; i--)
    {
        bool isHigh = true;
        bool isLow = true;

        for (int j = 1; j <= Depth; j++)
        {
            if ((i + j >= rates_total) || (i - j < 0)) {
                isHigh = false;
                isLow = false;
                break;
            }

            if (high[i] <= high[i + j] || high[i] < high[i - j])
                isHigh = false;
            if (low[i] >= low[i + j] || low[i] > low[i - j])
                isLow = false;
        }

        if (isHigh)
        {
            for (int back = 1; back <= Backstep && (i + back) < rates_total; back++)
            {
                if (ZigZagBuffer[i + back] > high[i])
                    ZigZagBuffer[i + back] = 0;
            }
            ZigZagBuffer[i] = high[i];
            lastHighIndex = i;
        }
        else if (isLow)
        {
            for (int back = 1; back <= Backstep && (i + back) < rates_total; back++)
            {
                if (ZigZagBuffer[i + back] < low[i])
                    ZigZagBuffer[i + back] = 0;
            }
            ZigZagBuffer[i] = low[i];
            lastLowIndex = i;
        }
    }

    return rates_total;
}
