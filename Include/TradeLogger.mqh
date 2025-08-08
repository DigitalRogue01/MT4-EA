#ifndef __TRADE_LOGGER_MQH__
#define __TRADE_LOGGER_MQH__

string logFileName = "TradeLog.csv";

// === Initialize the log file with header (only once) ===
void InitLogger()
{
    int file = FileOpen(logFileName, FILE_CSV | FILE_READ | FILE_WRITE, ',');
    if (file != INVALID_HANDLE)
    {
        if (FileSize(file) == 0)
        {
            FileWrite(file, "DateTime", "Symbol", "Ticket", "Type", "Lots", "Price", "SL", "Comment");
        }
        FileClose(file);
    }
    else
    {
        Print("InitLogger: Could not create or open log file: ", GetLastError());
    }
}

// === Write a trade record to the log ===
void LogTrade(string type, int ticket, double lots, double price, double sl, string reason)
{
    int file = FileOpen(logFileName, FILE_CSV | FILE_READ | FILE_WRITE, ',');
    if (file == INVALID_HANDLE)
    {
        Print("LogTrade: Error opening log file: ", GetLastError());
        return;
    }

    FileSeek(file, 0, SEEK_END);  // Move to end of file to append

    FileWrite(file,
        TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
        Symbol(),
        ticket,
        type,
        DoubleToString(lots, 2),
        DoubleToString(price, Digits),
        DoubleToString(sl, Digits),
        reason
    );

    FileClose(file);
}
#endif
