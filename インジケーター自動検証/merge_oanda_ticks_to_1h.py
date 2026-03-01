#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd


def normalize_name(name: str) -> str:
    return "".join(ch for ch in str(name).strip().lower() if ch.isalnum())


def find_column(columns: Iterable[str], candidates: set[str]) -> str | None:
    mapping = {normalize_name(c): c for c in columns}
    for cand in candidates:
        col = mapping.get(normalize_name(cand))
        if col is not None:
            return col
    return None


def parse_timestamp(series: pd.Series) -> pd.DatetimeIndex:
    if np.issubdtype(series.dtype, np.number):
        num = pd.to_numeric(series, errors="coerce")
        max_abs = num.abs().max()
        unit = "ms" if max_abs > 1e11 else "s"
        ts = pd.to_datetime(num, unit=unit, utc=True, errors="coerce")
    else:
        ts = pd.to_datetime(series, utc=True, errors="coerce")
    if ts.isna().all():
        raise ValueError("日時列をパースできませんでした")
    return ts


def load_single_file(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, sep=None, engine="python", compression="infer")

    date_col = find_column(df.columns, {"date", "tradedate", "businessdate", "day"})
    time_col = find_column(df.columns, {"time", "tradetime", "timestampms", "hhmmss"})

    ts_col = find_column(
        df.columns,
        {
            "timestamp",
            "time",
            "datetime",
            "date",
            "opentime",
            "closetime",
            "unixtime",
            "epochtime",
        },
    )
    if ts_col is None and not (date_col and time_col):
        raise ValueError(f"日時列が見つかりません: {path.name}")

    bid_col = find_column(df.columns, {"bid", "bidprice", "b"})
    ask_col = find_column(df.columns, {"ask", "askprice", "a"})
    price_col = find_column(df.columns, {"price", "last", "close", "c", "mid", "midprice"})

    if date_col and time_col:
        dt_text = df[date_col].astype(str).str.strip() + " " + df[time_col].astype(str).str.strip()
        ts = pd.to_datetime(dt_text, utc=True, errors="coerce")
        if ts.isna().all():
            ts = pd.to_datetime(
                df[date_col].astype(str).str.replace(".", "-", regex=False)
                + " "
                + df[time_col].astype(str).str.strip(),
                utc=True,
                errors="coerce",
            )
        if ts.isna().all():
            raise ValueError(f"DATE/TIME列の結合パースに失敗: {path.name}")
    else:
        ts = parse_timestamp(df[ts_col])

    if bid_col and ask_col:
        price = (pd.to_numeric(df[bid_col], errors="coerce") + pd.to_numeric(df[ask_col], errors="coerce")) / 2.0
    elif price_col:
        price = pd.to_numeric(df[price_col], errors="coerce")
    else:
        raise ValueError(f"価格列が見つかりません(bid/ask or price): {path.name}")

    out = pd.DataFrame({"price": price.values}, index=ts)
    out = out[~out.index.isna()]
    out = out.dropna(subset=["price"])
    out = out.sort_index()
    return out


def to_ohlcv(ticks: pd.DataFrame, timeframe: str) -> pd.DataFrame:
    ohlc = ticks["price"].resample(timeframe).ohlc()
    vol = ticks["price"].resample(timeframe).count().rename("volume")
    bars = pd.concat([ohlc, vol], axis=1).dropna(subset=["open", "high", "low", "close"])
    bars = bars.reset_index().rename(columns={"index": "timestamp"})
    return bars


def main() -> None:
    parser = argparse.ArgumentParser(description="OANDA月次tick CSVを結合し任意時間足OHLCVへ変換")
    parser.add_argument("--input-dir", required=True, help="月次CSV(またはcsv.gz/zip)を置いたフォルダ")
    parser.add_argument("--output", default="data/usdjpy_1h.csv", help="出力先CSV")
    parser.add_argument("--timeframe", default="1h", help="リサンプリング足 (例: 5min, 15min, 1h)")
    parser.add_argument("--tz", default="UTC", help="出力タイムゾーン（既定: UTC）")
    args = parser.parse_args()

    in_dir = Path(args.input_dir)
    if not in_dir.exists():
        raise FileNotFoundError(f"入力フォルダが見つかりません: {in_dir}")

    files = sorted([p for p in in_dir.iterdir() if p.is_file() and p.suffix.lower() in {".csv", ".gz", ".zip"}])
    if not files:
        raise ValueError("入力フォルダにCSV系ファイルがありません")

    all_ticks = []
    for file in files:
        try:
            ticks = load_single_file(file)
            all_ticks.append(ticks)
            print(f"[OK] {file.name}: {len(ticks):,} ticks")
        except Exception as exc:
            print(f"[SKIP] {file.name}: {exc}")

    if not all_ticks:
        raise RuntimeError("読み込めるファイルがありませんでした")

    merged = pd.concat(all_ticks).sort_index()
    merged = merged[~merged.index.duplicated(keep="last")]

    if args.tz.upper() != "UTC":
        merged.index = merged.index.tz_convert(args.tz)

    bars = to_ohlcv(merged, args.timeframe)

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bars.to_csv(out_path, index=False)

    print("\n=== Done ===")
    print(f"入力ファイル数: {len(files)}")
    print(f"統合tick数   : {len(merged):,}")
    print(f"{args.timeframe}本数  : {len(bars):,}")
    print(f"出力先       : {out_path}")


if __name__ == "__main__":
    main()
