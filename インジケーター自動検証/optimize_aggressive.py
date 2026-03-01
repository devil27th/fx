#!/usr/bin/env python3
from __future__ import annotations

import itertools
import pandas as pd

from local_backtest import Config, apply_preset, parse_datetime, run_backtest


def main() -> None:
    raw = pd.read_csv("data/usdjpy_1h.csv")
    df = parse_datetime(raw)
    base = apply_preset(Config(), "aggressive")

    rows = []
    grid = itertools.product(
        [1.6, 1.7, 1.8],
        [3.2, 3.4, 3.6],
        [False, True],
        [1.0, 1.2, 1.4],
        [False, True],
        [False, True],
        [2, 3, 4],
    )

    for sl_mult, tp_mult, use_be, be_trigger, use_session, use_cooldown, cooldown_bars in grid:
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
    safe = res[(res["net"] > 0) & (res["dd"] <= 18000)].sort_values(["net", "dd"], ascending=[False, True])

    print("BEST_NET_TOP5")
    print(res.head(5).to_string(index=False))
    print("\nSAFE_TOP5(net>0, dd<=18000)")
    print("None" if safe.empty else safe.head(5).to_string(index=False))

    res.to_csv("result_grid_aggressive.csv", index=False)
    print("\nSaved: result_grid_aggressive.csv")


if __name__ == "__main__":
    main()
