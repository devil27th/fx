#!/usr/bin/env python3
from __future__ import annotations

import itertools
import pandas as pd

from local_backtest import Config, apply_preset, parse_datetime, run_backtest


def main() -> None:
    raw = pd.read_csv("data/usdjpy_5m.csv")
    df = parse_datetime(raw)
    base = apply_preset(Config(), "aggressive")

    rows = []
    grid = itertools.product(
        [1.6, 1.7, 1.8, 1.9],      # sl
        [3.0, 3.2, 3.4, 3.6],      # tp
        [False, True],             # use_be
        [1.0, 1.2, 1.4],           # be_trigger
        [False, True],             # use_session
        [True],                    # use_cooldown (DD抑制のため固定ON)
        [3, 4, 5, 6],              # cooldown bars
        [False, True],             # use_macd_dir
        [2.4, 2.8, 3.2],           # max_dev_atr
    )

    for sl_mult, tp_mult, use_be, be_trigger, use_session, use_cooldown, cooldown_bars, use_macd_dir, max_dev_atr in grid:
        if (not use_be) and be_trigger != 1.4:
            continue

        cfg = Config(**vars(base))
        cfg.sl_mult = sl_mult
        cfg.tp_mult = tp_mult
        cfg.use_be = use_be
        cfg.be_trigger = be_trigger
        cfg.use_session = use_session
        cfg.use_cooldown = use_cooldown
        cfg.cooldown_bars = cooldown_bars
        cfg.use_macd_dir = use_macd_dir
        cfg.max_dev_atr = max_dev_atr

        result, _ = run_backtest(df, cfg, "2025-01-01", "2026-02-28")
        if result["total_trades"] == 0:
            continue

        rows.append(
            {
                "sl": sl_mult,
                "tp": tp_mult,
                "be": use_be,
                "be_tr": be_trigger,
                "session": use_session,
                "cooldown": use_cooldown,
                "cd_bars": cooldown_bars,
                "macd_dir": use_macd_dir,
                "max_dev_atr": max_dev_atr,
                "net": round(result["net_pnl"], 0),
                "net_pct": round(result["net_pct"], 3),
                "dd": round(result["max_drawdown"], 0),
                "pf": round(float(result["profit_factor"]) if pd.notna(result["profit_factor"]) else 999.0, 3),
                "wr": round(result["win_rate"], 2),
                "trades": int(result["total_trades"]),
            }
        )

    res = pd.DataFrame(rows)
    if res.empty:
        print("No result")
        return

    res = res.sort_values(["net", "pf"], ascending=[False, False])
    safe = res[(res["net"] > 0) & (res["dd"] <= 20000)].sort_values(["net", "dd"], ascending=[False, True])

    print("BEST_NET_TOP10")
    print(res.head(10).to_string(index=False))
    print("\nSAFE_TOP10(net>0, dd<=20000)")
    print("None" if safe.empty else safe.head(10).to_string(index=False))

    res.to_csv("result_grid_aggressive_5m.csv", index=False)
    print("\nSaved: result_grid_aggressive_5m.csv")


if __name__ == "__main__":
    main()
