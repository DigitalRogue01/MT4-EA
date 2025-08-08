
//+------------------------------------------------------------------+
//|                           LiquidityTrader_ScoreFilter.mq4        |
//| EA with ADX Penalty + DI Reversal Bonus (Dynamic)               |
//+------------------------------------------------------------------+
#property strict

extern double ADX_SuppressSweepThreshold = 30;
extern string TradeMode = "SweepOnly";
extern int ZoneLookback = 20;
extern double RiskPercent = 2.0;
extern double ATR_Multiplier = 1.5;
extern double EntryScoreThreshold = 3.0;
extern int MagicNumber = 123456;

double zoneHigh, zoneLow;

bool IsADXRising(int lookback = 3)
{
    for (int i = 1; i <= lookback; i++)
    {
        double adx_now = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MAIN, i);
        double adx_prev = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MAIN, i + 1);
        if (adx_now <= adx_prev)
            return false;
    }
    return true;
}

void OnTick()
{
    if (Bars < ZoneLookback + 10) return;

    double atr = iATR(Symbol(), 0, 14, 0);
    double adx = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MAIN, 0);
    double diPlus = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
    double diMinus = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MINUSDI, 1);

    double highLevel = High[iHighest(Symbol(), 0, MODE_HIGH, ZoneLookback, 1)];
    double lowLevel  = Low[iLowest(Symbol(), 0, MODE_LOW, ZoneLookback, 1)];
    zoneHigh = highLevel;
    zoneLow = lowLevel;

    DrawZone(zoneHigh, zoneLow);

    // Sweep score base
    double scoreBuy = 0, scoreSell = 0;
    string reasonBuy = "", reasonSell = "";

    if (Low[1] < zoneLow && Close[1] > zoneLow) { scoreBuy += 2; reasonBuy += "Wick+ "; }
    if (Close[1] > Open[1]) { scoreBuy += 1; reasonBuy += "BullBody+ "; }

    if (High[1] > zoneHigh && Close[1] < zoneHigh) { scoreSell += 2; reasonSell += "Wick+ "; }
    if (Close[1] < Open[1]) { scoreSell += 1; reasonSell += "BearBody+ "; }

    // ADX penalty
    int adxPenalty = IsADXRising(3) ? -1 : 0;

    // DI bonus (dynamic)
    double diBonusBuy = (scoreBuy > 0 && diPlus < diMinus) ? MathMin(2.0, MathAbs(diPlus - diMinus) / 10.0) : 0;
    double diBonusSell = (scoreSell > 0 && diMinus < diPlus) ? MathMin(2.0, MathAbs(diMinus - diPlus) / 10.0) : 0;

    scoreBuy += adxPenalty + diBonusBuy;
    scoreSell += adxPenalty + diBonusSell;

    if (OrdersTotal() == 0)
    {
        if ((TradeMode == "SweepOnly" || TradeMode == "Both") && scoreBuy >= EntryScoreThreshold)
            ExecuteTrade(OP_BUY, atr, scoreBuy, reasonBuy + "DI Bonus: " + DoubleToString(diBonusBuy, 2));
        if ((TradeMode == "SweepOnly" || TradeMode == "Both") && scoreSell >= EntryScoreThreshold)
            ExecuteTrade(OP_SELL, atr, scoreSell, reasonSell + "DI Bonus: " + DoubleToString(diBonusSell, 2));
    }

    Comment("ADX: ", DoubleToString(adx, 2),
            "\nZone High: ", DoubleToString(zoneHigh, Digits),
            " Zone Low: ", DoubleToString(zoneLow, Digits),
            "\nBuy Score: ", scoreBuy, " (", reasonBuy, ")",
            "\nSell Score: ", scoreSell, " (", reasonSell, ")");
}

void ExecuteTrade(int type, double atr, double score, string reason)
{
    double price = (type == OP_BUY) ? Ask : Bid;
    double sl = (type == OP_BUY) ? price - atr * ATR_Multiplier : price + atr * ATR_Multiplier;
    double tp = (type == OP_BUY) ? price + atr * ATR_Multiplier : price - atr * ATR_Multiplier;

    double risk = AccountBalance() * RiskPercent / 100.0;
    double stopLossPips = MathAbs(price - sl) / Point;
    double pipValue = 10.0;
    double lots = NormalizeDouble(risk / (stopLossPips * pipValue), 2);

    int ticket = OrderSend(Symbol(), type, lots, price, 3, sl, tp, "SweepTrade", MagicNumber, 0, clrBlue);
    if (ticket > 0)
    {
        string arrow = (type == OP_BUY) ? "BuyArrow_" + TimeToString(TimeCurrent(), TIME_SECONDS) : "SellArrow_" + TimeToString(TimeCurrent(), TIME_SECONDS);
        int arrowCode = (type == OP_BUY) ? 233 : 234;
        color arrowColor = (type == OP_BUY) ? clrBlue : clrRed;

        ObjectCreate(arrow, OBJ_ARROW, 0, Time[0], price);
        ObjectSetInteger(0, arrow, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, arrow, OBJPROP_COLOR, arrowColor);

        LogTrade(price, sl, tp, lots, type, score, reason);
    }
}

void DrawZone(double high, double low)
{
    string name = "LiquidityZone";
    if (ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, Time[ZoneLookback], high, Time[1], low);
    else
    {
        ObjectMove(0, name, 0, Time[ZoneLookback], high);
        ObjectMove(0, name, 1, Time[1], low);
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkSlateGray);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
}

void LogTrade(double entry, double sl, double tp, double lotSize, int type, double score, string reason)
{
    int handle = FileOpen("TradeLog.csv", FILE_CSV | FILE_WRITE);
    if (handle != INVALID_HANDLE)
    {
        FileSeek(handle, 0, SEEK_END);
        FileWrite(handle,
                  TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
                  (type == OP_BUY ? "BUY" : "SELL"),
                  DoubleToString(entry, Digits),
                  DoubleToString(sl, Digits),
                  DoubleToString(tp, Digits),
                  DoubleToString(lotSize, 2),
                  DoubleToString(score, 2),
                  reason);
        FileClose(handle);
    }
}
