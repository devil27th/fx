#!/usr/bin/env python3
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd


@dataclass
class Config:
    initial_capital: float = 100_000.0
    qty_pct: float = 100.0

    ma_fast_len: int = 20
    ma_slow_len: int = 50
    ma_type: str = "SMA"  # SMA or EMA

    st_factor: float = 3.0
    st_period: int = 10
    touch_margin_pips: float = 2.0


def parse_datetime(df: pd.DataFrame) -> pd.DataFrame:
    candidates = ["timestamp", "time", "datetime", "date"]
    dt_col = next((c for c in candidates if c in df.columns), None)
    if dt_col is None:
        raise ValueError("CSVに timestamp/time/datetime/date 列が必要です")

    if np.issubdtype(df[dt_col].dtype, np.number):
        num = pd.to_numeric(df[dt_col], errors="coerce")
        max_abs = num.abs().max()
        unit = "ms" if max_abs > 1e11 else "s"
        ts = pd.to_datetime(num, unit=unit, utc=True, errors="coerce")
    else:
        ts = pd.to_datetime(df[dt_col], utc=True, errors="coerce")

    if ts.isna().any():
        raise ValueError("日時列のパースに失敗した行があります")

    out = df.copy()
    out.index = ts
    out = out.sort_index()
    return out


def rma(series: pd.Series, length: int) -> pd.Series:
    alpha = 1 / length
    return series.ewm(alpha=alpha, adjust=False).mean()


def calc_atr(df: pd.DataFrame, length: int) -> pd.Series:
    prev_close = df["close"].shift(1)
    tr = pd.concat(
        [
            (df["high"] - df["low"]).abs(),
            (df["high"] - prev_close).abs(),
            (df["low"] - prev_close).abs(),
        ],
        axis=1,
    ).max(axis=1)
    return rma(tr, length)


def calc_supertrend(df: pd.DataFrame, period: int, factor: float) -> tuple[pd.Series, pd.Series]:
    atr = calc_atr(df, period)
    hl2 = (df["high"] + df["low"]) / 2.0
    upper = hl2 + factor * atr
    lower = hl2 - factor * atr

    final_upper = upper.copy()
    final_lower = lower.copy()
    direction = pd.Series(index=df.index, dtype="int64")
    st = pd.Series(index=df.index, dtype="float64")

    direction.iloc[0] = -1
    st.iloc[0] = lower.iloc[0]

    for i in range(1, len(df)):
        if upper.iloc[i] < final_upper.iloc[i - 1] or df["close"].iloc[i - 1] > final_upper.iloc[i - 1]:
            final_upper.iloc[i] = upper.iloc[i]
        else:
            final_upper.iloc[i] = final_upper.iloc[i - 1]

        if lower.iloc[i] > final_lower.iloc[i - 1] or df["close"].iloc[i - 1] < final_lower.iloc[i - 1]:
            final_lower.iloc[i] = lower.iloc[i]
        else:
            final_lower.iloc[i] = final_lower.iloc[i - 1]

        prev_dir = direction.iloc[i - 1]
        if prev_dir == -1:
            direction.iloc[i] = -1 if df["close"].iloc[i] >= final_lower.iloc[i] else 1
        else:
            direction.iloc[i] = 1 if df["close"].iloc[i] <= final_upper.iloc[i] else -1

        st.iloc[i] = final_lower.iloc[i] if direction.iloc[i] == -1 else final_upper.iloc[i]

    return st, direction


def build_heikin_ashi(df: pd.DataFrame) -> pd.DataFrame:
    ha = pd.DataFrame(index=df.index)
    ha["ha_close"] = (df["open"] + df["high"] + df["low"] + df["close"]) / 4.0

    ha_open = np.zeros(len(df), dtype=float)
    ha_open[0] = (df["open"].iloc[0] + df["close"].iloc[0]) / 2.0
    for i in range(1, len(df)):
        ha_open[i] = (ha_open[i - 1] + ha["ha_close"].iloc[i - 1]) / 2.0

    ha["ha_open"] = ha_open
    ha["ha_high"] = pd.concat([df["high"], ha["ha_open"], ha["ha_close"]], axis=1).max(axis=1)
    ha["ha_low"] = pd.concat([df["low"], ha["ha_open"], ha["ha_close"]], axis=1).min(axis=1)
    return ha


def run_backtest(df_raw: pd.DataFrame, cfg: Config, start: str | None, end: str | None) -> tuple[dict, pd.DataFrame]:
    if start:
        df_raw = df_raw[df_raw.index >= pd.to_datetime(start, utc=True)]
    if end:
        df_raw = df_raw[df_raw.index <= pd.to_datetime(end, utc=True)]

    ha = build_heikin_ashi(df_raw)
    data = pd.DataFrame(index=df_raw.index)
    data["open"] = ha["ha_open"]
    data["high"] = ha["ha_high"]
    data["low"] = ha["ha_low"]
    data["close"] = ha["ha_close"]

    if cfg.ma_type.upper() == "EMA":
        data["ma_fast"] = data["close"].ewm(span=cfg.ma_fast_len, adjust=False).mean()
        data["ma_slow"] = data["close"].ewm(span=cfg.ma_slow_len, adjust=False).mean()
    else:
        data["ma_fast"] = data["close"].rolling(cfg.ma_fast_len).mean()
        data["ma_slow"] = data["close"].rolling(cfg.ma_slow_len).mean()

    data["st"], data["st_dir"] = calc_supertrend(data, cfg.st_period, cfg.st_factor)
    data = data.dropna().copy()

    # infer pip / mintick-like unit from price resolution in data
    closes = data["close"].values
    diffs = np.unique(np.abs(np.diff(np.unique(np.round(closes, 8)))))
    min_step = float(diffs[diffs > 0].min()) if diffs.size and (diffs > 0).any() else 0.01
    pip_unit = min_step * 10.0
    touch_margin = cfg.touch_margin_pips * pip_unit

    equity = cfg.initial_capital
    position = 0  # 1 long, -1 short, 0 none
    units = 0.0
    entry_price = np.nan

    touched_ma_long = False
    touched_ma_short = False

    trades = []
    equity_curve = []

    for i in range(1, len(data)):
        row = data.iloc[i]
        prev = data.iloc[i - 1]

        gc = row.ma_fast > row.ma_slow
        dc = row.ma_fast < row.ma_slow

        bull_candle = row.close > row.open
        bear_candle = row.close < row.open

        # GC/DC切替で待機状態リセット
        if row.ma_fast > row.ma_slow and prev.ma_fast <= prev.ma_slow:
            touched_ma_long = False
        if row.ma_fast < row.ma_slow and prev.ma_fast >= prev.ma_slow:
            touched_ma_short = False

        pos_sign = position

        if gc and pos_sign <= 0:
            if row.low <= (row.ma_fast + touch_margin) or row.low <= (row.ma_slow + touch_margin):
                touched_ma_long = True
            if row.low < row.ma_slow:
                touched_ma_long = False

        if dc and pos_sign >= 0:
            if row.high >= (row.ma_fast - touch_margin) or row.high >= (row.ma_slow - touch_margin):
                touched_ma_short = True
            if row.high > row.ma_slow:
                touched_ma_short = False

        buy_signal = pos_sign <= 0 and gc and touched_ma_long and bull_candle
        sell_signal = pos_sign >= 0 and dc and touched_ma_short and bear_candle

        ma_fast_down = row.ma_fast < prev.ma_fast
        ma_fast_up = row.ma_fast > prev.ma_fast

        exit_long_tp = pos_sign == 1 and ma_fast_down and (not buy_signal)
        exit_long_sl = pos_sign == 1 and row.st_dir > 0 and (not buy_signal)
        exit_short_tp = pos_sign == -1 and ma_fast_up and (not sell_signal)
        exit_short_sl = pos_sign == -1 and row.st_dir < 0 and (not sell_signal)

        # ロング側
        if buy_signal:
            if position == -1:
                pnl = (entry_price - row.close) * units
                equity += pnl
                trades.append(
                    {
                        "time": data.index[i],
                        "side": "SHORT",
                        "entry": entry_price,
                        "exit": row.close,
                        "pnl": pnl,
                        "reason": "ReverseToLong",
                    }
                )
            notional = equity * (cfg.qty_pct / 100)
            units = notional / row.close
            entry_price = row.close
            position = 1
            touched_ma_long = False

        elif exit_long_tp and position == 1:
            pnl = (row.close - entry_price) * units
            equity += pnl
            trades.append(
                {
                    "time": data.index[i],
                    "side": "LONG",
                    "entry": entry_price,
                    "exit": row.close,
                    "pnl": pnl,
                    "reason": "TP_MA_down",
                }
            )
            position = 0
            units = 0.0
            entry_price = np.nan

        elif exit_long_sl and position == 1:
            pnl = (row.close - entry_price) * units
            equity += pnl
            trades.append(
                {
                    "time": data.index[i],
                    "side": "LONG",
                    "entry": entry_price,
                    "exit": row.close,
                    "pnl": pnl,
                    "reason": "SL_ST_flip",
                }
            )
            position = 0
            units = 0.0
            entry_price = np.nan

        # ショート側
        if sell_signal:
            if position == 1:
                pnl = (row.close - entry_price) * units
                equity += pnl
                trades.append(
                    {
                        "time": data.index[i],
                        "side": "LONG",
                        "entry": entry_price,
                        "exit": row.close,
                        "pnl": pnl,
                        "reason": "ReverseToShort",
                    }
                )
            notional = equity * (cfg.qty_pct / 100)
            units = notional / row.close
            entry_price = row.close
            position = -1
            touched_ma_short = False

        elif exit_short_tp and position == -1:
            pnl = (entry_price - row.close) * units
            equity += pnl
            trades.append(
                {
                    "time": data.index[i],
                    "side": "SHORT",
                    "entry": entry_price,
                    "exit": row.close,
                    "pnl": pnl,
                    "reason": "TP_MA_up",
                }
            )
            position = 0
            units = 0.0
            entry_price = np.nan

        elif exit_short_sl and position == -1:
            pnl = (entry_price - row.close) * units
            equity += pnl
            trades.append(
                {
                    "time": data.index[i],
                    "side": "SHORT",
                    "entry": entry_price,
                    "exit": row.close,
                    "pnl": pnl,
                    "reason": "SL_ST_flip",
                }
            )
            position = 0
            units = 0.0
            entry_price = np.nan

        mark_to_market = equity
        if position == 1:
            mark_to_market += (row.close - entry_price) * units
        elif position == -1:
            mark_to_market += (entry_price - row.close) * units
        equity_curve.append(mark_to_market)

    if position != 0 and len(data) > 0:
        last_close = data["close"].iloc[-1]
        if position == 1:
            pnl = (last_close - entry_price) * units
            side = "LONG"
        else:
            pnl = (entry_price - last_close) * units
            side = "SHORT"
        equity += pnl
        trades.append(
            {
                "time": data.index[-1],
                "side": side,
                "entry": entry_price,
                "exit": last_close,
                "pnl": pnl,
                "reason": "FinalClose",
            }
        )

    trades_df = pd.DataFrame(trades)
    total = len(trades_df)
    wins = int((trades_df["pnl"] > 0).sum()) if total else 0
    losses = int((trades_df["pnl"] <= 0).sum()) if total else 0
    gross_profit = float(trades_df.loc[trades_df["pnl"] > 0, "pnl"].sum()) if total else 0.0
    gross_loss = float(trades_df.loc[trades_df["pnl"] <= 0, "pnl"].sum()) if total else 0.0
    pf = gross_profit / abs(gross_loss) if gross_loss < 0 else np.nan
    win_rate = (wins / total * 100) if total else 0.0
    net = equity - cfg.initial_capital

    max_dd = 0.0
    if equity_curve:
        eq = pd.Series(equity_curve)
        max_dd = float((eq.cummax() - eq).max())

    result = {
        "initial_capital": cfg.initial_capital,
        "final_equity": equity,
        "net_pnl": net,
        "net_pct": (net / cfg.initial_capital) * 100,
        "total_trades": total,
        "win_rate": win_rate,
        "profit_factor": pf,
        "max_drawdown": max_dd,
        "avg_win": float(trades_df.loc[trades_df["pnl"] > 0, "pnl"].mean()) if wins else 0.0,
        "avg_loss": float(trades_df.loc[trades_df["pnl"] <= 0, "pnl"].mean()) if losses else 0.0,
    }
    return result, trades_df


def print_result(result: dict) -> None:
    print("\n=== Heikin Ashi MA Touch (5m) Summary ===")
    print(f"Initial Capital : {result['initial_capital']:.0f}")
    print(f"Final Equity    : {result['final_equity']:.0f}")
    print(f"Net PnL         : {result['net_pnl']:.0f} ({result['net_pct']:.2f}%)")
    print(f"Trades          : {result['total_trades']}")
    print(f"Win Rate        : {result['win_rate']:.2f}%")
    print(f"Profit Factor   : {result['profit_factor']:.2f}" if pd.notna(result["profit_factor"]) else "Profit Factor   : inf")
    print(f"Max Drawdown    : {result['max_drawdown']:.0f}")
    print(f"Avg Win / Loss  : {result['avg_win']:.0f} / {result['avg_loss']:.0f}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Heikin Ashi MA Touch Strategy v4 の5分足ローカル検証")
    parser.add_argument("--csv", default="data/usdjpy_5m.csv", help="5分足OHLCV CSV")
    parser.add_argument("--start", default=None, help="開始日時(例: 2025-01-01)")
    parser.add_argument("--end", default=None, help="終了日時(例: 2026-02-28)")
    parser.add_argument("--ma-type", default="SMA", choices=["SMA", "EMA"], help="MAタイプ")
    parser.add_argument("--out-trades", default="result_trades_ha_touch_5m.csv", help="トレード履歴CSV出力先")
    args = parser.parse_args()

    path = Path(args.csv)
    if not path.exists():
        raise FileNotFoundError(f"CSVが見つかりません: {path}")

    raw = pd.read_csv(path)
    required = {"open", "high", "low", "close"}
    if not required.issubset(raw.columns):
        raise ValueError("CSVには open, high, low, close 列が必要です")

    df = parse_datetime(raw)
    cfg = Config(ma_type=args.ma_type)

    result, trades = run_backtest(df, cfg, args.start, args.end)
    print_result(result)

    if args.out_trades:
        out_path = Path(args.out_trades)
        trades.to_csv(out_path, index=False)
        print(f"\nトレード履歴を出力しました: {out_path}")


if __name__ == "__main__":
    main()
