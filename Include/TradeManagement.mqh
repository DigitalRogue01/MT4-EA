#ifndef __TRADE_MANAGEMENT_MQH__
#define __TRADE_MANAGEMENT_MQH__

#include <LotSize_Calculations.mqh>
#include <OpenTrade.mqh>

// === Internal Flags ===
bool scaledOut = false;

// === Main Management Function ===
void ManageOpenTrade()
{
    // Always select the active trade on current chart
    bool found = false;
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderSymbol() == Symbol() &&
                OrderMagicNumber() == MagicNumber &&
                (OrderType() == OP_BUY || OrderType() == OP_SELL))
            {
                found = true;
                break;
            }
        }
    }
    if (!found)
    {
        ResetActiveTradeTicket();
        scaledOut = false;
        return;
    }

    // Prevent management on same candle trade was opened
    if (OrderOpenTime() >= Time[0]) return;

    // SCALE OUT + BREAKEVEN
    if (!scaledOut && PriceReachedScaleOutLevel())
    {
        MoveStopToBreakeven();
        CloseHalfLotSize();
        scaledOut = true;
    }

    // PSAR EXIT
    if (ShouldExitTrade())
    {
        CloseTrade();
        ResetActiveTradeTicket();
        scaledOut = false;
    }
}

// === Scale-Out Trigger Check ===
bool PriceReachedScaleOutLevel()
{
    double entry = OrderOpenPrice();
    double targetDist = GetATRTakeProfitDistance();
    bool isBuy = (OrderType() == OP_BUY);

    return (isBuy && Bid - entry >= targetDist) ||
           (!isBuy && entry - Ask >= targetDist);
}

// === Move SL to BreakEven ===
void MoveStopToBreakeven()
{
    double bePrice = OrderOpenPrice();
    bool isBuy = (OrderType() == OP_BUY);

    if ((isBuy && OrderStopLoss() < bePrice) ||
        (!isBuy && OrderStopLoss() > bePrice))
    {
        if (!OrderModify(OrderTicket(), OrderOpenPrice(), bePrice, 0, 0, clrYellow))
            Print("SL to breakeven failed: ", GetLastError());
    }
}

// === Close Half Position ===
void CloseHalfLotSize()
{
    double half = OrderLots() / 2.0;
    double price = (OrderType() == OP_BUY) ? Bid : Ask;

    if (!OrderClose(OrderTicket(), half, price, 3, clrOrange))
        Print("Scale-out failed: ", GetLastError());
}

// === Exit on PSAR Flip (Previous Candle) ===
bool ShouldExitTrade()
{
    bool isBuy = (OrderType() == OP_BUY);

    double psarPrev = iSAR(Symbol(), 0, 0.06, 0.2, 1);
    double closePrev = Close[1];

    if (isBuy && psarPrev > closePrev) return true;
    if (!isBuy && psarPrev < closePrev) return true;

    return false;
}

// === Full Trade Close ===
void CloseTrade()
{
    double lots = OrderLots();
    double price = (OrderType() == OP_BUY) ? Bid : Ask;

    if (!OrderClose(OrderTicket(), lots, price, 3, clrRed))
        Print("Close failed: ", GetLastError());
}

#endif
