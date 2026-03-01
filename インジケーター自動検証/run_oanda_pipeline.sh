#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR="${1:-$ROOT_DIR/data/oanda_ticks}"
PRESET="${2:-neutral}"
START_DATE="${3:-2018-01-01}"
END_DATE="${4:-2025-12-31}"
TZ_NAME="${5:-UTC}"

OUT_1H="$ROOT_DIR/data/usdjpy_1h.csv"
OUT_TRADES="$ROOT_DIR/result_trades_${PRESET}.csv"

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "[ERROR] 入力フォルダが見つかりません: $INPUT_DIR"
  echo "使い方: ./run_oanda_pipeline.sh [input_dir] [preset] [start] [end] [tz]"
  exit 1
fi

mkdir -p "$ROOT_DIR/data"

if [[ ! -d "$ROOT_DIR/.venv" ]]; then
  python3 -m venv "$ROOT_DIR/.venv"
fi

source "$ROOT_DIR/.venv/bin/activate"
pip install -q -r "$ROOT_DIR/requirements.txt"

python "$ROOT_DIR/merge_oanda_ticks_to_1h.py" \
  --input-dir "$INPUT_DIR" \
  --output "$OUT_1H" \
  --tz "$TZ_NAME"

python "$ROOT_DIR/local_backtest.py" \
  --csv "$OUT_1H" \
  --preset "$PRESET" \
  --start "$START_DATE" \
  --end "$END_DATE" \
  --out-trades "$OUT_TRADES"

echo ""
echo "=== 完了 ==="
echo "1時間足CSV : $OUT_1H"
echo "トレードCSV: $OUT_TRADES"
