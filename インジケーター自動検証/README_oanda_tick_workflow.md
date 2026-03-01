# OANDA月次Tickをローカルで長期検証に使う手順

TradingView無料版で長期検証できない場合の代替フローです。

## 1. OANDAサイトで月ごとにダウンロード

- 対象通貨: USDJPY
- 期間: 1か月ずつ
- ダウンロードしたファイルを、同じフォルダに保存（例: `data/oanda_ticks/`）

例:
- `data/oanda_ticks/USDJPY_2024-01.csv`
- `data/oanda_ticks/USDJPY_2024-02.csv`
- `data/oanda_ticks/USDJPY_2024-03.csv`

## 2. 月次tickを結合して1時間足CSVへ変換

```bash
cd /Users/yumeng/work/private/インジケーター自動検証
source .venv/bin/activate
python merge_oanda_ticks_to_1h.py \
  --input-dir data/oanda_ticks \
  --output data/usdjpy_1h.csv \
  --tz UTC
```

- 列名はある程度自動判定（`time/timestamp`、`bid/ask` or `price`）
- 区切り文字は自動判定
- `csv.gz` / `zip` にも対応

## 3. バックテスト実行

```bash
python local_backtest.py \
  --csv data/usdjpy_1h.csv \
  --preset neutral \
  --start 2018-01-01 \
  --end 2025-12-31 \
  --out-trades result_trades_neutral.csv
```

## 4. プリセット比較

```bash
python local_backtest.py --csv data/usdjpy_1h.csv --preset conservative --start 2018-01-01 --end 2025-12-31
python local_backtest.py --csv data/usdjpy_1h.csv --preset neutral      --start 2018-01-01 --end 2025-12-31
python local_backtest.py --csv data/usdjpy_1h.csv --preset aggressive   --start 2018-01-01 --end 2025-12-31
```

## 5. 一発実行（結合→変換→検証）

```bash
cd /Users/yumeng/work/private/インジケーター自動検証
chmod +x run_oanda_pipeline.sh
./run_oanda_pipeline.sh data/oanda_ticks neutral 2018-01-01 2025-12-31 UTC
```

引数:
- 第1引数: 月次tickフォルダ
- 第2引数: preset (`conservative` / `neutral` / `aggressive` / `manual`)
- 第3引数: 開始日
- 第4引数: 終了日
- 第5引数: タイムゾーン

## 注意

- こちらからOANDA口座にログインしてダウンロード代行はできません。
- ただし、月次ファイルを置くだけで「結合→1時間足化→検証」は自動化できます。
