# ローカル長期検証ガイド（TradingView無料版の代替）

## 1) 準備

```bash
cd /Users/yumeng/work/private/インジケーター自動検証
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 2) データ形式
CSVは最低限、以下の列が必要です。

- `timestamp` または `time` または `datetime` または `date`
- `open`, `high`, `low`, `close`
- `volume` は任意

日時はUTC推奨です。

このツールは以下も自動対応します。

- 区切り文字: カンマ/タブ/セミコロンを自動判定
- 列名別名: `o,h,l,c` / `Open,High,Low,Close` / `last,price` などを標準列に自動変換
- Unix時刻: 秒(`s`)とミリ秒(`ms`)を値の桁数から自動判定

## 3) 実行例

```bash
python local_backtest.py \
  --csv data/usdjpy_1h.csv \
  --preset neutral \
  --start 2018-01-01 \
  --end 2025-12-31 \
  --out-trades result_trades_neutral.csv
```

プリセット:
- `conservative`（保守）
- `neutral`（中立）
- `aggressive`（攻め）
- `manual`（手動・現状はコード既定値）

## 4) 比較実行（推奨）

```bash
python local_backtest.py --csv data/usdjpy_1h.csv --preset conservative --start 2018-01-01 --end 2025-12-31
python local_backtest.py --csv data/usdjpy_1h.csv --preset neutral      --start 2018-01-01 --end 2025-12-31
python local_backtest.py --csv data/usdjpy_1h.csv --preset aggressive   --start 2018-01-01 --end 2025-12-31
```

確認指標:
- Net PnL
- Profit Factor
- Max Drawdown
- Win Rate
- Trades（取引数）

## 5) 注意点（Pineとの完全一致について）

このテンプレートは、`usdjpy_1h_pro_v4.pine` のロジックを**近似再現**しています。
以下は環境差でズレます。

- 約定モデル（バー内でSL/TP同時ヒット時の優先順位）
- ブローカーのスプレッド変動
- TradingView固有の約定タイミング

まずはローカルで長期の傾向を見て、最終確認をTradingView側で行う運用が安全です。
