//+------------------------------------------------------------------+
//|                   PrecisionScout.mq4 - Live Version              |
//|  Optimized trend EA with ADX/DI+/PSAR filtering and scale-out   |
//+------------------------------------------------------------------+
#property strict

#include <LotSize_Calculations.mqh>
#include <OpenTrade.mqh>
#include <TradeManagement.mqh>
#include <TradeLogger.mqh>
#include <ErrorHandler.mqh>

//--- Inputs
input int    MagicNumber             = 123456;
input bool   EnableTrading           = true;
input double RiskPercent             = 2.0;
input int    ATRPeriod               = 14;
input double ATRMultiplier           = 1.5;
input double ADX_Minimum             = 37.5;
input int    ADX_Period              = 14;
input bool   RequireADXIncreasing    = true;
input double MinDIDistance           = 5.0;
input double PSAR_Step               = 0.07;
input double PSAR_Max                = 0.2;

//--- Internal
datetime lastTradeCandle = 0;

//--- ADX Filter
bool PassesADXFilter() {
   double adxNow  = iADX(Symbol(), 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   double adxPrev = iADX(Symbol(), 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 2);

   if (adxNow <= ADX_Minimum) {
      Print("Blocked: ADX too low (", DoubleToString(adxNow, 2), " < ", ADX_Minimum, ")");
      return false;
   }
   if (RequireADXIncreasing && adxNow < adxPrev) {
      Print("Blocked: ADX declining (", DoubleToString(adxNow, 2), " < ", DoubleToString(adxPrev, 2), ")");
      return false;
   }
   return true;
}

//--- DI+ Gap
bool DIAlignmentSupportsTrade(bool isBuy) {
   double diPlus  = iADX(Symbol(), 0, ADX_Period, PRICE_CLOSE, MODE_PLUSDI, 1);
   double diMinus = iADX(Symbol(), 0, ADX_Period, PRICE_CLOSE, MODE_MINUSDI, 1);
   double gap = MathAbs(diPlus - diMinus);

   if (isBuy && diPlus > diMinus && gap >= MinDIDistance) return true;
   if (!isBuy && diMinus > diPlus && gap >= MinDIDistance) return true;

   Print("Blocked: DI gap too small or wrong direction (Gap=", DoubleToString(gap, 2), ")");
   return false;
}

//--- PSAR Alignment
bool PSARAlignedWithDirection(bool isBuy) {
   double psar = iSAR(Symbol(), 0, PSAR_Step, PSAR_Max, 1);
   double price = Close[1];
   bool aligned = (isBuy && psar < price) || (!isBuy && psar > price);
   if (!aligned)
      Print("Blocked: PSAR misaligned (PSAR=", DoubleToString(psar, 5), ", Price=", DoubleToString(price, 5), ")");
   return aligned;
}

//--- Signals
bool IsBuySignal() {
   return PassesADXFilter() && DIAlignmentSupportsTrade(true) && PSARAlignedWithDirection(true) && (Close[1] > Open[1]);
}

bool IsSellSignal() {
   return PassesADXFilter() && DIAlignmentSupportsTrade(false) && PSARAlignedWithDirection(false) && (Close[1] < Open[1]);
}

//--- Trade Check
bool IsTradeOpen() {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber &&
             (OrderType() == OP_BUY || OrderType() == OP_SELL))
            return true;
      }
   }
   return false;
}

//--- Main Logic
void OnTick() {
   if (!EnableTrading) return;
   if (Time[0] == lastTradeCandle) return;

   if (!IsTradeOpen()) {
      if (IsBuySignal()) {
         if (OpenBuy()) {
            lastTradeCandle = Time[0];
            LogTrade("BUY", OrderTicket(), OrderLots(), Ask, OrderStopLoss(), "Buy Entry");
         } else {
            PrintTradeError("OpenBuy");
         }
      } else if (IsSellSignal()) {
         if (OpenSell()) {
            lastTradeCandle = Time[0];
            LogTrade("SELL", OrderTicket(), OrderLots(), Bid, OrderStopLoss(), "Sell Entry");
         } else {
            PrintTradeError("OpenSell");
         }
      }
   } else {
      ManageOpenTrade();
      if (!IsTradeOpen()) lastTradeCandle = Time[0];
   }
}

//--- Init
int OnInit() {
   InitLogger();
   return INIT_SUCCEEDED;
}
