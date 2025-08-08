#ifndef __OPEN_TRADE_MQH__
#define __OPEN_TRADE_MQH__

#include <LotSize_Calculations.mqh>

// External
// extern int MagicNumber = 123456;

// Internal state
int activeTradeTicket = -1;

// === Open Buy ===
bool OpenBuy()
{
    double stopLossPrice = Bid - GetATRStopDistance();
    double takeProfitPrice = Bid + GetATRTakeProfitDistance();
    double lotsToTrade = CalculateLotSize(stopLossPrice, true);

    int ticket = OrderSend(Symbol(), OP_BUY, lotsToTrade, Ask, 3,
                           stopLossPrice, 0,
                           "Buy Entry", MagicNumber, 0, clrBlue);

    if (ticket < 0)
    {
        Print("Buy order failed: ", ErrorDescription(GetLastError()));
        return false;
    }

    activeTradeTicket = ticket;
    return true;
}

// === Open Sell ===
bool OpenSell()
{
    double stopLossPrice = Ask + GetATRStopDistance();
    double takeProfitPrice = Ask - GetATRTakeProfitDistance();
    double lotsToTrade = CalculateLotSize(stopLossPrice, false);

    int ticket = OrderSend(Symbol(), OP_SELL, lotsToTrade, Bid, 3,
                           stopLossPrice, 0,
                           "Sell Entry", MagicNumber, 0, clrRed);

    if (ticket < 0)
    {
        Print("Sell order failed: ", ErrorDescription(GetLastError()));
        return false;
    }

    activeTradeTicket = ticket;
    return true;
}

double GetATRStopDistance()
{
    return iATR(Symbol(), 0, ATRPeriod, 0) * ATRMultiplier;
}

double GetATRTakeProfitDistance()
{
    return iATR(Symbol(), 0, ATRPeriod, 0); // 1x ATR
}

int GetActiveTradeTicket() { return activeTradeTicket; }
void ResetActiveTradeTicket() { activeTradeTicket = -1; }

