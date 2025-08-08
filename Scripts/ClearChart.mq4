//+------------------------------------------------------------------+
//| Script    : ClearChart.mq4                                       |
//| Purpose   : Remove all objects and indicators from the current   |
//|             chart and its subwindows.                            |
//+------------------------------------------------------------------+
#property strict

void OnStart()
{
   long chart_id = ChartID();

   // Delete ALL graphical objects in all windows of the chart.
   // Passing subwindow = 0 and type = -1 removes every object:contentReference[oaicite:1]{index=1}.
   // Repeat for each sub-window to be safe.
   ObjectsDeleteAll(chart_id, 0, -1);  // main window
   int total_subwindows = (int)ChartGetInteger(chart_id, CHART_WINDOWS_TOTAL);
   for(int w=1; w<total_subwindows; w++)
      ObjectsDeleteAll(chart_id, w, -1);

   // Remove all indicators from each subwindow.
   // Loop backwards when deleting to avoid index shifting.
   for(int w=0; w<total_subwindows; w++)
   {
      int ind_total = ChartIndicatorsTotal(chart_id, w);
      for(int i=ind_total-1; i>=0; i--)
      {
         string ind_name = ChartIndicatorName(chart_id, w, i);
         if(ind_name != "")
            ChartIndicatorDelete(chart_id, w, ind_name);
      }
   }

   // Optionally, force a chart refresh
   ChartRedraw();
}
