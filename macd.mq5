//+------------------------------------------------------------------+
//|                   MTF MACD Dashboard (1H / 4H / D / M)          |
//|                   Created by ChatGPT (GPT-5)                    |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

input int FastEMA = 12;
input int SlowEMA = 26;
input int SignalSMA = 9;

//--- 時間足を定義
ENUM_TIMEFRAMES timeframes[4] = { PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_MN1 };
string tf_names[4] = { "1H", "4H", "D", "M" };

//--- 描画位置設定
input int corner = 0;        // 0=左上, 1=右上, 2=左下, 3=右下
input int x_offset = 10;
input int y_offset = 20;
input color positiveColor = clrLime;
input color negativeColor = clrRed;
input color neutralColor  = clrSilver;
input string fontName = "Arial";
input int fontSize = 10;

int OnInit()
{
   EventSetTimer(2); // 2秒ごとに更新
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, "MTF_MACD_");
}

void OnTimer()
{
   DrawDashboard();
}

void DrawDashboard()
{
   // 既存テキスト削除
   for (int i = 0; i < 4; i++)
      ObjectDelete(0, "MTF_MACD_" + tf_names[i]);

   int spacing = 18;
   for (int i = 0; i < 4; i++)
   {
      double macd_main[], macd_signal[], macd_hist[];
      int copied = iMACD(NULL, timeframes[i], FastEMA, SlowEMA, SignalSMA, PRICE_CLOSE, macd_main, macd_signal, macd_hist);
      if (copied < 1) continue;

      double latest_hist = macd_hist[0];
      color txtColor = (latest_hist > 0) ? positiveColor : (latest_hist < 0) ? negativeColor : neutralColor;

      string label = "MTF_MACD_" + tf_names[i];
      string text = StringFormat("%s:  %.5f", tf_names[i], latest_hist);

      ObjectCreate(0, label, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, label, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, label, OBJPROP_XDISTANCE, x_offset);
      ObjectSetInteger(0, label, OBJPROP_YDISTANCE, y_offset + (i * spacing));
      ObjectSetString(0, label, OBJPROP_TEXT, text);
      ObjectSetInteger(0, label, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, label, OBJPROP_FONT, fontName);
      ObjectSetInteger(0, label, OBJPROP_COLOR, txtColor);
   }
}