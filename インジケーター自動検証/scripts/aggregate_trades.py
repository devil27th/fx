#!/usr/bin/env python3
import pandas as pd
from pathlib import Path
p=Path('result_trades_ha_touch_5m.csv')
if not p.exists():
    print(f"CSV not found: {p}")
    raise SystemExit(1)

df=pd.read_csv(p)
if df.empty:
    print('トレード履歴が空です')
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

print('=== 集計結果 (result_trades_ha_touch_5m.csv) ===')
print(f"Total trades : {total}")
print(f"Net PnL      : {net:.2f}")
print(f"Gross Profit : {gross_profit:.2f}")
print(f"Gross Loss   : {gross_loss:.2f}")
print(f"Profit Factor: {pf:.2f}" if pf!=float('inf') else 'Profit Factor: inf')
print(f"Win Rate     : {win_rate:.2f}% ({wins}/{total})")
print(f"Avg Win/Loss : {avg_win:.2f} / {avg_loss:.2f}")
print(f"Max Drawdown : {max_dd:.2f}")

print('\n--- サイド別 ---')
for side in ['LONG','SHORT']:
    sub=df[df['side']==side]
    if len(sub)==0:
        continue
    nn=len(sub)
    nnet=sub['pnl'].sum()
    nwin=(sub['pnl']>0).sum()
    nwr = nwin/nn*100
    print(f"{side}: trades={nn}, net={nnet:.2f}, win_rate={nwr:.2f}%")

print('\nファイル: result_trades_ha_touch_5m.csv')
