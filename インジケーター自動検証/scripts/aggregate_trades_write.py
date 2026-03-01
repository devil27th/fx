#!/usr/bin/env python3
import pandas as pd
from pathlib import Path
p=Path('result_trades_ha_touch_5m.csv')
out=Path('result_trades_ha_touch_5m_summary.txt')
if not p.exists():
    print(f"CSV not found: {p}")
    raise SystemExit(1)

df=pd.read_csv(p)
if df.empty:
    out.write_text('トレード履歴が空です')
    raise SystemExit(0)

initial_cap = 100000.0

total=len(df)
net=df['pnl'].sum()
gross_profit=df.loc[df['pnl']>0,'pnl'].sum()
gross_loss=df.loc[df['pnl']<=0,'pnl'].sum()
pf = gross_profit / -gross_loss if gross_loss<0 else float('inf')
wins=(df['pnl']>0).sum()
win_rate = wins/total*100 if total else 0
avg_win = df.loc[df['pnl']>0,'pnl'].mean() if wins else 0
avg_loss = df.loc[df['pnl']<=0,'pnl'].mean() if (total-wins) else 0

equity = (df['pnl'].cumsum()+initial_cap)
max_dd = (equity.cummax() - equity).max()

lines = []
lines.append('=== 集計結果 (result_trades_ha_touch_5m.csv) ===')
lines.append(f"Total trades : {total}")
lines.append(f"Net PnL      : {net:.2f}")
lines.append(f"Gross Profit : {gross_profit:.2f}")
lines.append(f"Gross Loss   : {gross_loss:.2f}")
lines.append(f"Profit Factor: {pf:.2f}" if pf!=float('inf') else 'Profit Factor: inf')
lines.append(f"Win Rate     : {win_rate:.2f}% ({wins}/{total})")
lines.append(f"Avg Win/Loss : {avg_win:.2f} / {avg_loss:.2f}")
lines.append(f"Max Drawdown : {max_dd:.2f}")
lines.append('\n--- サイド別 ---')
for side in ['LONG','SHORT']:
    sub=df[df['side']==side]
    if len(sub)==0:
        continue
    nn=len(sub)
    nnet=sub['pnl'].sum()
    nwin=(sub['pnl']>0).sum()
    nwr = nwin/nn*100
    lines.append(f"{side}: trades={nn}, net={nnet:.2f}, win_rate={nwr:.2f}%")

out.write_text('\n'.join(lines))
print(f"Wrote summary to {out}")
