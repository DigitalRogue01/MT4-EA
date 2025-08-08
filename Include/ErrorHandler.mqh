//+------------------------------------------------------------------+
//|                                                 ErrorHandler.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict
string ErrorDescription(int code)
{
   switch(code)
   {
      case 1: return "No error returned";
      case 2: return "Common error";
      case 3: return "Invalid trade parameters";
      case 4: return "Trade server busy";
      case 5: return "Old version of the client terminal";
      case 6: return "No connection with trade server";
      case 7: return "Not enough rights";
      case 8: return "Too frequent requests";
      case 9: return "Malfunctional trade operation";
      case 64: return "Account disabled";
      case 65: return "Invalid account";
      case 133: return "Trading is prohibited";
      case 134: return "Not enough money";
      case 135: return "Price changed";
      case 136: return "No prices";
      case 137: return "Broker is busy";
      case 138: return "Requote";
      case 139: return "Order is locked";
      case 140: return "Long positions only allowed";
      case 141: return "Too many requests";
      default: return "Unknown error (" + IntegerToString(code) + ")";
   }
}
void PrintTradeError(string context)
{
   int errorCode = GetLastError();
   Print("ERROR [", context, "]: Code=", errorCode, " | ", ErrorDescription(errorCode));
   ResetLastError();
}
