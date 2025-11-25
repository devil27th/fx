//+------------------------------------------------------------------+
//|                                          MyStrategy_MT5.mq5      |
//|                        自作ストラテジー MT5版                      |
//|                        SuperTrend + MA クロス戦略                 |
//+------------------------------------------------------------------+
#property copyright "Converted from Pine Script"
#property link      ""
#property version   "1.00"

//--- インプットパラメータ
input group "=== SuperTrend設定 ==="
input int    InpATRPeriod = 9;           // ATR期間
input double InpMultiplier = 3.9;        // ATR乗数

input group "=== 移動平均設定 ==="
input int    InpMAFastPeriod = 20;       // 短期MA期間
input int    InpMASlowPeriod = 75;       // 長期MA期間
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // MA種類

input group "=== リスク管理 ==="
input double InpRiskPercent = 1.0;       // リスク% (資金の)
input double InpATRSLMultiplier = 1.5;   // ATR SL倍率
input double InpRRRatio = 3.0;           // リスクリワード比
input double InpMinTPPips = 20.0;        // 最小利確PIPS
input bool   InpUseATRStops = true;      // ATRベースSL/TP使用
input bool   InpPartialTP = true;        // 部分利確有効
input double InpPartialRatio = 1.5;      // 部分利確R倍率

input group "=== フィルター ==="
input bool   InpUseTrendFilter = true;   // トレンドフィルター使用
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H4; // トレンド判定時間足
input int    InpTrendEMAPeriod = 200;    // トレンドEMA期間

input group "=== 取引設定 ==="
input double InpLotSize = 0.1;           // ロットサイズ (固定)
input bool   InpUseRiskSizing = false;   // リスクベースサイジング使用
input int    InpMagicNumber = 123456;    // マジックナンバー
input string InpTradeComment = "MyStrategy"; // 注文コメント

//--- グローバル変数
int atrHandle;
int maFastHandle;
int maSlowHandle;
int maTrendHandle;

double atrBuffer[];
double maFastBuffer[];
double maSlowBuffer[];
double maTrendBuffer[];

int prevTrend = 0;
bool hasPartialClosed = false;

//+------------------------------------------------------------------+
//| エキスパート初期化関数                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- インジケーターハンドル作成
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   maFastHandle = iMA(_Symbol, PERIOD_CURRENT, InpMAFastPeriod, 0, InpMAMethod, PRICE_CLOSE);
   maSlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpMASlowPeriod, 0, InpMAMethod, PRICE_CLOSE);
   maTrendHandle = iMA(_Symbol, InpTrendTF, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(atrHandle == INVALID_HANDLE || maFastHandle == INVALID_HANDLE || 
      maSlowHandle == INVALID_HANDLE || maTrendHandle == INVALID_HANDLE)
   {
      Print("インジケーターの作成に失敗しました");
      return(INIT_FAILED);
   }
   
   //--- 配列を時系列として設定
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(maFastBuffer, true);
   ArraySetAsSeries(maSlowBuffer, true);
   ArraySetAsSeries(maTrendBuffer, true);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| エキスパート削除関数                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- インジケーターハンドル解放
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(maFastHandle != INVALID_HANDLE) IndicatorRelease(maFastHandle);
   if(maSlowHandle != INVALID_HANDLE) IndicatorRelease(maSlowHandle);
   if(maTrendHandle != INVALID_HANDLE) IndicatorRelease(maTrendHandle);
}

//+------------------------------------------------------------------+
//| エキスパートティック関数                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- 新しいバーチェック
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;
   
   //--- インジケーターデータ取得
   if(CopyBuffer(atrHandle, 0, 0, 3, atrBuffer) < 3) return;
   if(CopyBuffer(maFastHandle, 0, 0, 3, maFastBuffer) < 3) return;
   if(CopyBuffer(maSlowHandle, 0, 0, 3, maSlowBuffer) < 3) return;
   if(CopyBuffer(maTrendHandle, 0, 0, 3, maTrendBuffer) < 3) return;
   
   //--- 価格データ取得
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 3, close) < 3) return;
   
   //--- SuperTrend計算
   int currentTrend = CalculateSuperTrend(close);
   
   //--- シグナル判定
   bool buySignal = (currentTrend == 1 && prevTrend == -1);  // SuperTrend反転（上昇）
   bool sellSignal = (currentTrend == -1 && prevTrend == 1); // SuperTrend反転（下降）
   
   //--- MAクロス確認
   bool goldenCross = (maFastBuffer[0] > maSlowBuffer[0] && maFastBuffer[1] <= maSlowBuffer[1]);
   bool deathCross = (maFastBuffer[0] < maSlowBuffer[0] && maFastBuffer[1] >= maSlowBuffer[1]);
   
   //--- トレンドフィルター
   bool longTrend = true;
   bool shortTrend = true;
   if(InpUseTrendFilter)
   {
      longTrend = (close[0] > maTrendBuffer[0]);
      shortTrend = (close[0] < maTrendBuffer[0]);
   }
   
   //--- シグナル統合（SuperTrend + MAクロス + トレンドフィルター）
   buySignal = (buySignal || goldenCross) && longTrend;
   sellSignal = (sellSignal || deathCross) && shortTrend;
   
   //--- 既存ポジション確認
   int posType = GetPositionType();
   
   //--- 取引実行
   if(buySignal && posType != 1)
   {
      if(posType == -1) CloseAllPositions(); // 反対ポジションクローズ
      OpenBuyPosition();
      hasPartialClosed = false;
   }
   else if(sellSignal && posType != -1)
   {
      if(posType == 1) CloseAllPositions(); // 反対ポジションクローズ
      OpenSellPosition();
      hasPartialClosed = false;
   }
   
   //--- 部分利確チェック
   if(InpPartialTP && !hasPartialClosed)
      CheckPartialTP();
   
   //--- トレンド状態更新
   prevTrend = currentTrend;
}

//+------------------------------------------------------------------+
//| SuperTrend計算                                                    |
//+------------------------------------------------------------------+
int CalculateSuperTrend(const double &close[])
{
   static double up = 0, dn = 0;
   static int trend = 1;
   
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 3, high) < 3) return trend;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 3, low) < 3) return trend;
   
   double hl2 = (high[0] + low[0]) / 2.0;
   double atr = atrBuffer[0];
   
   double newUp = hl2 - InpMultiplier * atr;
   double newDn = hl2 + InpMultiplier * atr;
   
   up = (close[1] > up) ? MathMax(newUp, up) : newUp;
   dn = (close[1] < dn) ? MathMin(newDn, dn) : newDn;
   
   if(trend == -1 && close[0] > dn)
      trend = 1;
   else if(trend == 1 && close[0] < up)
      trend = -1;
   
   return trend;
}

//+------------------------------------------------------------------+
//| ポジションタイプ取得                                               |
//+------------------------------------------------------------------+
int GetPositionType()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| 買いポジションオープン                                             |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = atrBuffer[0];
   
   //--- SL/TP計算
   double sl = InpUseATRStops ? ask - InpATRSLMultiplier * atr : ask * (1 - InpRiskPercent / 100);
   double risk = ask - sl;
   double tp = InpUseATRStops ? ask + risk * InpRRRatio : ask * (1 + InpRRRatio * InpRiskPercent / 100);
   
   //--- 最小PIPS保証
   double minTP = ask + InpMinTPPips * _Point * 10;
   if(tp < minTP) tp = minTP;
   
   //--- ロット計算
   double lots = InpLotSize;
   if(InpUseRiskSizing)
   {
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double riskPips = risk / tickSize;
      lots = NormalizeDouble(riskAmount / (riskPips * tickValue), 2);
   }
   
   //--- 最小/最大ロット確認
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lots = MathMax(minLot, MathMin(lots, maxLot));
   
   //--- 注文送信
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lots;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.magic = InpMagicNumber;
   request.comment = InpTradeComment;
   request.deviation = 10;
   
   if(!OrderSend(request, result))
      Print("買い注文エラー: ", GetLastError());
   else
      Print("買いポジションオープン: ", lots, " lots @ ", ask);
}

//+------------------------------------------------------------------+
//| 売りポジションオープン                                             |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = atrBuffer[0];
   
   //--- SL/TP計算
   double sl = InpUseATRStops ? bid + InpATRSLMultiplier * atr : bid * (1 + InpRiskPercent / 100);
   double risk = sl - bid;
   double tp = InpUseATRStops ? bid - risk * InpRRRatio : bid * (1 - InpRRRatio * InpRiskPercent / 100);
   
   //--- 最小PIPS保証
   double minTP = bid - InpMinTPPips * _Point * 10;
   if(tp > minTP) tp = minTP;
   
   //--- ロット計算
   double lots = InpLotSize;
   if(InpUseRiskSizing)
   {
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double riskPips = risk / tickSize;
      lots = NormalizeDouble(riskAmount / (riskPips * tickValue), 2);
   }
   
   //--- 最小/最大ロット確認
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lots = MathMax(minLot, MathMin(lots, maxLot));
   
   //--- 注文送信
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lots;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.magic = InpMagicNumber;
   request.comment = InpTradeComment;
   request.deviation = 10;
   
   if(!OrderSend(request, result))
      Print("売り注文エラー: ", GetLastError());
   else
      Print("売りポジションオープン: ", lots, " lots @ ", bid);
}

//+------------------------------------------------------------------+
//| 全ポジションクローズ                                               |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_DEAL;
         request.position = ticket;
         request.symbol = _Symbol;
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         request.magic = InpMagicNumber;
         request.deviation = 10;
         
         OrderSend(request, result);
      }
   }
}

//+------------------------------------------------------------------+
//| 部分利確チェック                                                   |
//+------------------------------------------------------------------+
void CheckPartialTP()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         double risk = MathAbs(openPrice - sl);
         double profit = MathAbs(currentPrice - openPrice);
         
         //--- 1.5R到達で50%利確
         if(profit >= risk * InpPartialRatio)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double halfVolume = NormalizeDouble(volume / 2, 2);
            
            if(halfVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_DEAL;
               request.position = ticket;
               request.symbol = _Symbol;
               request.volume = halfVolume;
               request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
               request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                              SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               request.magic = InpMagicNumber;
               request.comment = "Partial TP";
               request.deviation = 10;
               
               if(OrderSend(request, result))
               {
                  Print("部分利確実行: ", halfVolume, " lots");
                  hasPartialClosed = true;
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
