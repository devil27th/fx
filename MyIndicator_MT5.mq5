//+------------------------------------------------------------------+
//|                                            MyIndicator_MT5.mq5   |
//|                        自作インジケーター MT5版                    |
//|                        主要機能: SuperTrend + MTF MA + Fibo      |
//+------------------------------------------------------------------+
#property copyright "Converted from Pine Script"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   10

//--- SuperTrend
#property indicator_label1  "SuperTrend Up"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "SuperTrend Down"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- MTF MA (4時間足)
#property indicator_label3  "MA 4H"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//--- MTF MA (日足)
#property indicator_label4  "MA 1D"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMagenta
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

//--- MTF MA (週足)
#property indicator_label5  "MA 1W"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrBlack
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

//--- ボリンジャーバンド
#property indicator_label6  "BB Middle"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrRed
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

#property indicator_label7  "BB +1σ"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrGreen
#property indicator_style7  STYLE_DOT
#property indicator_width7  1

#property indicator_label8  "BB -1σ"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrGreen
#property indicator_style8  STYLE_DOT
#property indicator_width8  1

#property indicator_label9  "BB +2σ"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrRed
#property indicator_style9  STYLE_DOT
#property indicator_width9  1

#property indicator_label10 "BB -2σ"
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrRed
#property indicator_style10 STYLE_DOT
#property indicator_width10 1

//--- インプットパラメータ
input group "=== SuperTrend ==="
input int    InpATRPeriod = 9;           // ATR期間
input double InpMultiplier = 3.9;        // ATR乗数
input bool   InpShowSuperTrend = true;   // SuperTrend表示

input group "=== マルチタイムフレーム移動平均 ==="
input bool   InpShowMTF = false;          // MTF MA表示 (推奨: 別インジケーターを使用)
input int    InpMAPeriod = 20;           // MA期間
input ENUM_MA_METHOD InpMAMethod = MODE_EMA; // MA種類

input group "=== ボリンジャーバンド ==="
input bool   InpShowBB = true;           // BB表示
input int    InpBBPeriod = 21;           // BB期間
input double InpBBDeviation = 2.0;       // BB偏差

input group "=== 前日高値安値 ==="
input bool   InpShowYesterday = true;    // 前日高値安値表示
input color  InpYesterdayHighColor = clrGreen;  // 前日高値色
input color  InpYesterdayLowColor = clrRed;     // 前日安値色

input group "=== BUY/SELLシグナル ==="
input bool   InpShowSignals = true;      // シグナル表示
input int    InpArrowSize = 3;           // 矢印サイズ (1-5)
input color  InpBuyColor = clrLime;      // BUYシグナル色
input color  InpSellColor = clrRed;      // SELLシグナル色

//--- インジケーターバッファ
double SuperTrendUpBuffer[];
double SuperTrendDownBuffer[];
double MA4HBuffer[];
double MA1DBuffer[];
double MA1WBuffer[];
double BBMiddleBuffer[];
double BBUpper1Buffer[];
double BBLower1Buffer[];
double BBUpper2Buffer[];
double BBLower2Buffer[];

//--- 作業用バッファ
double UpBuffer[];
double DnBuffer[];
double TrendBuffer[];
double ATRBuffer[];
double StdDevBuffer[];

//--- グローバル変数
int atrHandle;
int ma4HHandle;
int ma1DHandle;
int ma1WHandle;
datetime lastYesterdayTime = 0;
double yesterdayHigh = 0;
double yesterdayLow = 0;

//+------------------------------------------------------------------+
//| カスタムインジケーター初期化関数                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- インジケーターバッファのマッピング
   SetIndexBuffer(0, SuperTrendUpBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SuperTrendDownBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, MA4HBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, MA1DBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, MA1WBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, BBMiddleBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, BBUpper1Buffer, INDICATOR_DATA);
   SetIndexBuffer(7, BBLower1Buffer, INDICATOR_DATA);
   SetIndexBuffer(8, BBUpper2Buffer, INDICATOR_DATA);
   SetIndexBuffer(9, BBLower2Buffer, INDICATOR_DATA);
   
   //--- 作業用バッファ
   SetIndexBuffer(10, UpBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, DnBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, TrendBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, ATRBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, StdDevBuffer, INDICATOR_CALCULATIONS);
   
   //--- 配列を時系列として設定
   ArraySetAsSeries(SuperTrendUpBuffer, true);
   ArraySetAsSeries(SuperTrendDownBuffer, true);
   ArraySetAsSeries(MA4HBuffer, true);
   ArraySetAsSeries(MA1DBuffer, true);
   ArraySetAsSeries(MA1WBuffer, true);
   ArraySetAsSeries(BBMiddleBuffer, true);
   ArraySetAsSeries(BBUpper1Buffer, true);
   ArraySetAsSeries(BBLower1Buffer, true);
   ArraySetAsSeries(BBUpper2Buffer, true);
   ArraySetAsSeries(BBLower2Buffer, true);
   ArraySetAsSeries(UpBuffer, true);
   ArraySetAsSeries(DnBuffer, true);
   ArraySetAsSeries(TrendBuffer, true);
   ArraySetAsSeries(ATRBuffer, true);
   ArraySetAsSeries(StdDevBuffer, true);
   
   //--- バッファ初期化
   ArrayInitialize(SuperTrendUpBuffer, EMPTY_VALUE);
   ArrayInitialize(SuperTrendDownBuffer, EMPTY_VALUE);
   ArrayInitialize(MA4HBuffer, EMPTY_VALUE);
   ArrayInitialize(MA1DBuffer, EMPTY_VALUE);
   ArrayInitialize(MA1WBuffer, EMPTY_VALUE);
   ArrayInitialize(BBMiddleBuffer, EMPTY_VALUE);
   ArrayInitialize(BBUpper1Buffer, EMPTY_VALUE);
   ArrayInitialize(BBLower1Buffer, EMPTY_VALUE);
   ArrayInitialize(BBUpper2Buffer, EMPTY_VALUE);
   ArrayInitialize(BBLower2Buffer, EMPTY_VALUE);
   
   //--- ATRインジケーターハンドル作成
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("ATRインジケーターの作成に失敗しました");
      return(INIT_FAILED);
   }
   
   //--- MTF MAハンドル作成
   if(InpShowMTF)
   {
      ma4HHandle = iMA(_Symbol, PERIOD_H4, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);
      ma1DHandle = iMA(_Symbol, PERIOD_D1, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);
      ma1WHandle = iMA(_Symbol, PERIOD_W1, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);
      
      if(ma4HHandle == INVALID_HANDLE || ma1DHandle == INVALID_HANDLE || ma1WHandle == INVALID_HANDLE)
      {
         Print("MTF MAインジケーターの作成に失敗しました");
         // エラーでも続行（MTF MAなしで動作）
         ma4HHandle = INVALID_HANDLE;
         ma1DHandle = INVALID_HANDLE;
         ma1WHandle = INVALID_HANDLE;
      }
   }
   else
   {
      ma4HHandle = INVALID_HANDLE;
      ma1DHandle = INVALID_HANDLE;
      ma1WHandle = INVALID_HANDLE;
   }
   
   //--- 小数点桁数設定
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   //--- インジケーター名設定
   IndicatorSetString(INDICATOR_SHORTNAME, "自作インジケーター MT5");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| カスタムインジケーター削除関数                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- インジケーターハンドル解放
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   
   if(ma4HHandle != INVALID_HANDLE)
      IndicatorRelease(ma4HHandle);
   if(ma1DHandle != INVALID_HANDLE)
      IndicatorRelease(ma1DHandle);
   if(ma1WHandle != INVALID_HANDLE)
      IndicatorRelease(ma1WHandle);
      
   //--- オブジェクト削除
   ObjectsDeleteAll(0, "YesterdayHigh");
   ObjectsDeleteAll(0, "YesterdayLow");
   ObjectsDeleteAll(0, "BuySignal_");
   ObjectsDeleteAll(0, "SellSignal_");
}

//+------------------------------------------------------------------+
//| カスタムインジケーター反復関数                                      |
//+------------------------------------------------------------------+
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
   //--- 配列を時系列として設定
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   //--- 計算開始位置
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   
   //--- ATRデータ取得
   if(CopyBuffer(atrHandle, 0, 0, rates_total, ATRBuffer) <= 0)
      return(0);
   
   //--- SuperTrend計算
   if(InpShowSuperTrend)
      CalculateSuperTrend(rates_total, start, high, low, close);
   
   //--- ボリンジャーバンド計算
   if(InpShowBB)
      CalculateBollingerBands(rates_total, start, close);
   
   //--- マルチタイムフレームMA計算
   if(InpShowMTF)
      CalculateMTFMA(rates_total, start);
   
   //--- 前日高値安値表示
   if(InpShowYesterday)
      DrawYesterdayLevels(time);
   
   //--- BUY/SELLシグナル表示
   if(InpShowSignals && InpShowSuperTrend)
      DrawSignals(rates_total, start, time, low, high);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| SuperTrend計算                                                    |
//+------------------------------------------------------------------+
void CalculateSuperTrend(const int rates_total, 
                         const int start,
                         const double &high[],
                         const double &low[],
                         const double &close[])
{
   for(int i = rates_total - 1; i >= start; i--)
   {
      double hl2 = (high[i] + low[i]) / 2.0;
      double atr = ATRBuffer[i];
      
      //--- Up/Dn計算
      double up = hl2 - InpMultiplier * atr;
      double dn = hl2 + InpMultiplier * atr;
      
      //--- 前バーの値
      double prevUp = (i < rates_total - 1) ? UpBuffer[i + 1] : up;
      double prevDn = (i < rates_total - 1) ? DnBuffer[i + 1] : dn;
      double prevClose = (i < rates_total - 1) ? close[i + 1] : close[i];
      
      //--- Up/Dn更新
      UpBuffer[i] = (prevClose > prevUp) ? MathMax(up, prevUp) : up;
      DnBuffer[i] = (prevClose < prevDn) ? MathMin(dn, prevDn) : dn;
      
      //--- トレンド判定
      double prevTrend = (i < rates_total - 1) ? TrendBuffer[i + 1] : 1;
      
      if(prevTrend == -1 && close[i] > prevDn)
         TrendBuffer[i] = 1;
      else if(prevTrend == 1 && close[i] < prevUp)
         TrendBuffer[i] = -1;
      else
         TrendBuffer[i] = prevTrend;
      
      //--- バッファ設定
      if(TrendBuffer[i] == 1)
      {
         SuperTrendUpBuffer[i] = UpBuffer[i];
         SuperTrendDownBuffer[i] = EMPTY_VALUE;
      }
      else
      {
         SuperTrendUpBuffer[i] = EMPTY_VALUE;
         SuperTrendDownBuffer[i] = DnBuffer[i];
      }
   }
}

//+------------------------------------------------------------------+
//| ボリンジャーバンド計算                                             |
//+------------------------------------------------------------------+
void CalculateBollingerBands(const int rates_total,
                              const int start,
                              const double &close[])
{
   for(int i = rates_total - 1; i >= start; i--)
   {
      if(i < rates_total - InpBBPeriod)
      {
         //--- SMA計算
         double sum = 0;
         for(int j = 0; j < InpBBPeriod; j++)
            sum += close[i + j];
         BBMiddleBuffer[i] = sum / InpBBPeriod;
         
         //--- 標準偏差計算
         double sumSq = 0;
         for(int j = 0; j < InpBBPeriod; j++)
         {
            double diff = close[i + j] - BBMiddleBuffer[i];
            sumSq += diff * diff;
         }
         double stdDev = MathSqrt(sumSq / InpBBPeriod);
         
         //--- バンド計算
         BBUpper1Buffer[i] = BBMiddleBuffer[i] + stdDev;
         BBLower1Buffer[i] = BBMiddleBuffer[i] - stdDev;
         BBUpper2Buffer[i] = BBMiddleBuffer[i] + stdDev * InpBBDeviation;
         BBLower2Buffer[i] = BBMiddleBuffer[i] - stdDev * InpBBDeviation;
      }
   }
}

//+------------------------------------------------------------------+
//| マルチタイムフレームMA計算                                          |
//+------------------------------------------------------------------+
void CalculateMTFMA(const int rates_total, const int start)
{
   //--- 時系列としてバッファを設定
   ArraySetAsSeries(MA4HBuffer, false);
   ArraySetAsSeries(MA1DBuffer, false);
   ArraySetAsSeries(MA1WBuffer, false);
   
   //--- 4時間足MA
   if(ma4HHandle != INVALID_HANDLE)
   {
      if(CopyBuffer(ma4HHandle, 0, 0, rates_total, MA4HBuffer) <= 0)
      {
         Print("4H MAデータ取得失敗");
         ArrayInitialize(MA4HBuffer, EMPTY_VALUE);
      }
   }
   
   //--- 日足MA
   if(ma1DHandle != INVALID_HANDLE)
   {
      if(CopyBuffer(ma1DHandle, 0, 0, rates_total, MA1DBuffer) <= 0)
      {
         Print("1D MAデータ取得失敗");
         ArrayInitialize(MA1DBuffer, EMPTY_VALUE);
      }
   }
   
   //--- 週足MA
   if(ma1WHandle != INVALID_HANDLE)
   {
      if(CopyBuffer(ma1WHandle, 0, 0, rates_total, MA1WBuffer) <= 0)
      {
         Print("1W MAデータ取得失敗");
         ArrayInitialize(MA1WBuffer, EMPTY_VALUE);
      }
   }
   
   //--- 時系列に戻す
   ArraySetAsSeries(MA4HBuffer, true);
   ArraySetAsSeries(MA1DBuffer, true);
   ArraySetAsSeries(MA1WBuffer, true);
}

//+------------------------------------------------------------------+
//| 前日高値安値描画                                                   |
//+------------------------------------------------------------------+
void DrawYesterdayLevels(const datetime &time[])
{
   //--- 日足が変わったか確認
   MqlDateTime dt;
   TimeToStruct(time[0], dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   
   if(today != lastYesterdayTime)
   {
      lastYesterdayTime = today;
      
      //--- 前日データ取得
      datetime yesterday = today - 86400;
      int dayIndex = iBarShift(_Symbol, PERIOD_D1, yesterday);
      
      if(dayIndex >= 0)
      {
         double highPrices[], lowPrices[];
         ArraySetAsSeries(highPrices, true);
         ArraySetAsSeries(lowPrices, true);
         
         if(CopyHigh(_Symbol, PERIOD_D1, dayIndex, 1, highPrices) > 0 &&
            CopyLow(_Symbol, PERIOD_D1, dayIndex, 1, lowPrices) > 0)
         {
            yesterdayHigh = highPrices[0];
            yesterdayLow = lowPrices[0];
            
            //--- 前日高値ライン
            string highName = "YesterdayHigh";
            ObjectDelete(0, highName);
            ObjectCreate(0, highName, OBJ_HLINE, 0, 0, yesterdayHigh);
            ObjectSetInteger(0, highName, OBJPROP_COLOR, InpYesterdayHighColor);
            ObjectSetInteger(0, highName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, highName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, highName, OBJPROP_BACK, true);
            ObjectSetString(0, highName, OBJPROP_TEXT, "前日高値: " + DoubleToString(yesterdayHigh, _Digits));
            
            //--- 前日安値ライン
            string lowName = "YesterdayLow";
            ObjectDelete(0, lowName);
            ObjectCreate(0, lowName, OBJ_HLINE, 0, 0, yesterdayLow);
            ObjectSetInteger(0, lowName, OBJPROP_COLOR, InpYesterdayLowColor);
            ObjectSetInteger(0, lowName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, lowName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lowName, OBJPROP_BACK, true);
            ObjectSetString(0, lowName, OBJPROP_TEXT, "前日安値: " + DoubleToString(yesterdayLow, _Digits));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BUY/SELLシグナル描画                                               |
//+------------------------------------------------------------------+
void DrawSignals(const int rates_total,
                 const int start,
                 const datetime &time[],
                 const double &low[],
                 const double &high[])
{
   // 安全チェック: 十分なバー数がない場合は処理しない
   if(rates_total < 2 || start >= rates_total - 1) return;

   // ループは i+1 を参照するため rates_total-2 までにする
   int i_start = MathMax(start, 0);
   int i_end = rates_total - 2;

   for(int i = i_end; i >= i_start; i--)
   {
      //--- トレンド転換を検出（prev は常に存在する）
      double currentTrend = TrendBuffer[i];
      double prevTrend = TrendBuffer[i + 1];

      //--- 上昇トレンドに転換（BUYシグナル）
      if(currentTrend == 1 && prevTrend == -1)
      {
         string objName = StringFormat("BuySignal_%u", (uint)time[i]);

         //--- 既存のオブジェクトを削除
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);

         //--- 矢印オブジェクト作成（上向き矢印）
         if(ObjectCreate(0, objName, OBJ_ARROW_BUY, 0, time[i], low[i]))
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, InpBuyColor);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpArrowSize);
            ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
            ObjectSetString(0, objName, OBJPROP_TEXT, "BUY");
         }
      }

      //--- 下降トレンドに転換（SELLシグナル）
      else if(currentTrend == -1 && prevTrend == 1)
      {
         string objName = StringFormat("SellSignal_%u", (uint)time[i]);

         //--- 既存のオブジェクトを削除
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);

         //--- 矢印オブジェクト作成（下向き矢印）
         if(ObjectCreate(0, objName, OBJ_ARROW_SELL, 0, time[i], high[i]))
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, InpSellColor);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpArrowSize);
            ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
            ObjectSetString(0, objName, OBJPROP_TEXT, "SELL");
         }
      }
   }
}
//+------------------------------------------------------------------+
