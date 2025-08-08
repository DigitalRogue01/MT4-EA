#property copyright "Jimmy Gray, Following my interpretation of NNFX.. Created with: ©2020 Visual Strategy Builder"
#property link "https://tools.forextester.com"
#property description ""
#property strict
#property indicator_chart_window
#property indicator_buffers 2
input bool DebugMode = false; //Write indicator actions to logs
int logFileHandle = INVALID_HANDLE;
datetime currentBar = 0;
datetime lastActR1 = 0;
datetime lastActR2 = 0;



int prev_bars;
double ArrowBufferR1A1[];
double ArrowBufferR2A1[];

int OnInit()
{
   IndicatorBuffers(2);
   SetIndexBuffer(0, ArrowBufferR1A1);
   SetIndexStyle(0, DRAW_ARROW, 0, 1, 16753152);
   SetIndexArrow(0, 217);
   SetIndexLabel(0, NULL);
   SetIndexBuffer(1, ArrowBufferR2A1);
   SetIndexStyle(1, DRAW_ARROW, 0, 1, 16753152);
   SetIndexArrow(1, 218);
   SetIndexLabel(1, NULL);
   if(logFileHandle != INVALID_HANDLE)
     FileClose(logFileHandle); 
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(logFileHandle != INVALID_HANDLE)
     FileClose(logFileHandle);
}

void WriteDebugLog(string logMessage)
{
   Print(logMessage);

   if (logFileHandle != INVALID_HANDLE)
     FileWriteString(logFileHandle, StringConcatenate(TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS), " " ,logMessage, "\r\n"));
}


int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
   currentBar = iTime(NULL, 0, 0);

   if(Bars < 20)
      return rates_total;
   
   int all = rates_total;
   int calculated = prev_calculated;

   if(all - calculated > 1)
   {
      ArrayInitialize(ArrowBufferR1A1,EMPTY_VALUE);
      ArrayInitialize(ArrowBufferR2A1,EMPTY_VALUE);
      calculated = 0;
   }

   for(int i=all - calculated;i>=0;i--)
   {
      if(i > Bars - 20)
         i = Bars - 20;

      if(i == 0)
      {
         ArrowBufferR1A1[i] = EMPTY_VALUE;
         ArrowBufferR2A1[i] = EMPTY_VALUE;
      }

   
      double AverageDirectionalMovementIndexR1C1O1[];
      ArrayResize(AverageDirectionalMovementIndexR1C1O1, 100);
      for(int i = 0; i <100; i++)
         AverageDirectionalMovementIndexR1C1O1[i] = iADX(Symbol(), 0, 14, 0, 0, i + 0);
   
      if(DebugMode)
      {
         WriteDebugLog("Process rule: ADX Trending Up");
         WriteDebugLog("Rule structure: DetectValuesTrend(AverageDirectionalMovementIndexR1C1O1, 100) == 1");
         WriteDebugLog(StringConcatenate("Rule values: "));
      }
   
      if(DetectValuesTrend(AverageDirectionalMovementIndexR1C1O1, 100) == 1)
      {
         if(DebugMode)
         {
            WriteDebugLog("Condition of rule \"ADX Trending Up\" met");
            WriteDebugLog("Performing actions...");
         }
         if(lastActR1 != currentBar)
         {
            lastActR1 = currentBar;
         if(i == 1)
               Comment("ADX Up");
      
         ArrowBufferR1A1[i] = Low[i] - 7 * Point;
         }
         else
         {
            ArrowBufferR1A1[i] = EMPTY_VALUE;
         }
      }
      else
      {
         ArrowBufferR1A1[i] = EMPTY_VALUE;
         if (DebugMode)
            WriteDebugLog("Condition of rule \"ADX Trending Up\" not met");
      }
      
      double AverageDirectionalMovementIndexR2C1O1[];
      ArrayResize(AverageDirectionalMovementIndexR2C1O1, 100);
      for(int i = 0; i <100; i++)
         AverageDirectionalMovementIndexR2C1O1[i] = iADX(Symbol(), 0, 14, 0, 0, i + 0);
   
      if(DebugMode)
      {
         WriteDebugLog("Process rule: ADX Trending Down");
         WriteDebugLog("Rule structure: DetectValuesTrend(AverageDirectionalMovementIndexR2C1O1, 100) == -1");
         WriteDebugLog(StringConcatenate("Rule values: "));
      }
   
      if(DetectValuesTrend(AverageDirectionalMovementIndexR2C1O1, 100) == -1)
      {
         if(DebugMode)
         {
            WriteDebugLog("Condition of rule \"ADX Trending Down\" met");
            WriteDebugLog("Performing actions...");
         }
         if(lastActR2 != currentBar)
         {
            lastActR2 = currentBar;
         if(i == 1)
               Comment("ADX Down");
      
         ArrowBufferR2A1[i] = Low[i] - 7 * Point;
         }
         else
         {
            ArrowBufferR2A1[i] = EMPTY_VALUE;
         }
      }
      else
      {
         ArrowBufferR2A1[i] = EMPTY_VALUE;
         if (DebugMode)
            WriteDebugLog("Condition of rule \"ADX Trending Down\" not met");
      }
   }

   if(Bars==prev_bars)
      return(rates_total);

   prev_bars=Bars;
   return rates_total;
}
double PipPoint(string Currency)
{
	double CalcPoint = 0.0;
	int CalcDigits = MarketInfo(Currency,MODE_DIGITS);
	if(CalcDigits == 2 || CalcDigits == 3) 
		CalcPoint = 0.01;
	else if(CalcDigits == 4 || CalcDigits == 5) 
		CalcPoint = 0.0001;
	
	return (CalcPoint);
}