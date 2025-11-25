//+------------------------------------------------------------------+

//| MyIndicator_MT5_MTF.mq5                                          |

//| MTF moving averages: H1, H4, D1, MN1                              |

//+------------------------------------------------------------------+

#property copyright "Converted"

#property version "1.00"

#property indicator_chart_window

#property indicator_buffers 4

#property indicator_plots 4

#property indicator_label1 "MA_1H"

#property indicator_type1 DRAW_LINE

#property indicator_color1 clrDodgerBlue

#property indicator_style1 STYLE_SOLID

#property indicator_width1 2

#property indicator_label2 "MA_4H"

#property indicator_type2 DRAW_LINE

#property indicator_color2 clrOrange

#property indicator_style2 STYLE_DOT

#property indicator_width2 2

#property indicator_label3 "MA_D"

#property indicator_type3 DRAW_LINE

#property indicator_color3 clrGreen

#property indicator_style3 STYLE_DASH

#property indicator_width3 2

#property indicator_label4 "MA_M"

#property indicator_type4 DRAW_LINE

#property indicator_color4 clrRed

#property indicator_style4 STYLE_DASHDOT

#property indicator_width4 2

//--- inputs

input int InpMAPeriod = 20; // MA period

input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // MA method

input bool InpInterpolate = true; // interpolate between HTF points

input int InpMaxHTFBars = 1024; // max HTF bars to copy

//--- buffers

double ma1H[], ma4H[], maD[], maM[];

//--- MA handles

int ma1HHandle = INVALID_HANDLE;

int ma4HHandle = INVALID_HANDLE;

int maDHandle = INVALID_HANDLE;

int maMHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+

int OnInit()

{

	//--- set buffers (non-time-series: oldest->newest)

	SetIndexBuffer(0, ma1H, INDICATOR_DATA);

	SetIndexBuffer(1, ma4H, INDICATOR_DATA);

	SetIndexBuffer(2, maD, INDICATOR_DATA);

	SetIndexBuffer(3, maM, INDICATOR_DATA);

	ArraySetAsSeries(ma1H, false);

	ArraySetAsSeries(ma4H, false);

	ArraySetAsSeries(maD, false);

	ArraySetAsSeries(maM, false);

	ArrayInitialize(ma1H, EMPTY_VALUE);

	ArrayInitialize(ma4H, EMPTY_VALUE);

	ArrayInitialize(maD, EMPTY_VALUE);

	ArrayInitialize(maM, EMPTY_VALUE);

	//--- create MA handles

	ma1HHandle = iMA(_Symbol, PERIOD_H1, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);

	ma4HHandle = iMA(_Symbol, PERIOD_H4, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);

	maDHandle = iMA(_Symbol, PERIOD_D1, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);

	maMHandle = iMA(_Symbol, PERIOD_MN1, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);

	if (ma1HHandle == INVALID_HANDLE)
		Print("Warning: ma1H handle invalid");

	if (ma4HHandle == INVALID_HANDLE)
		Print("Warning: ma4H handle invalid");

	if (maDHandle == INVALID_HANDLE)
		Print("Warning: maD handle invalid");

	if (maMHandle == INVALID_HANDLE)
		Print("Warning: maM handle invalid");

	IndicatorSetString(INDICATOR_SHORTNAME, "MTF MA (H1,H4,D,M)");

	return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+

void OnDeinit(const int reason)

{

	if (ma1HHandle != INVALID_HANDLE)
		IndicatorRelease(ma1HHandle);

	if (ma4HHandle != INVALID_HANDLE)
		IndicatorRelease(ma4HHandle);

	if (maDHandle != INVALID_HANDLE)
		IndicatorRelease(maDHandle);

	if (maMHandle != INVALID_HANDLE)
		IndicatorRelease(maMHandle);
}

//+------------------------------------------------------------------+

// find index k in times[0..count-1] (oldest->newest) where times[k] <= t < times[k+1]

int FindIndexByTime(datetime &times[], int count, datetime t)

{

	if (count <= 0)
		return -1;

	if (t < times[0])
		return -1;

	int l = 0, r = count - 1;

	while (l <= r)

	{

		int m = (l + r) >> 1;

		if (times[m] == t)
			return m;

		if (times[m] < t)
			l = m + 1;
		else
			r = m - 1;
	}

	return r; // last index <= t
}

//+------------------------------------------------------------------+

int OnCalculate(const int rates_total,

				const int prev_calculated,

				const datetime &time[],

				const double &open[],

				const double &high[],

				const double &low[],

				const double &close[],

				const long &tick_volume[],

				const long &volume[],

				const int &spread[])

{

	if (rates_total <= 0)
		return (0);

	int toCopy = MathMin(rates_total, InpMaxHTFBars);

	//--- allocate temp arrays (oldest->newest)

	double buf1[];
	datetime t1[];

	double buf4[];
	datetime t4[];

	double bufD[];
	datetime tD[];

	double bufM[];
	datetime tM[];

	int c1 = 0, c4 = 0, cD = 0, cM = 0;

	if (ma1HHandle != INVALID_HANDLE)

	{

		ArraySetAsSeries(buf1, false);
		ArraySetAsSeries(t1, false);

		c1 = CopyBuffer(ma1HHandle, 0, 0, toCopy, buf1);

		c1 = MathMin(c1, CopyTime(_Symbol, PERIOD_H1, 0, toCopy, t1));

		if (c1 <= 0)
			c1 = 0;
	}

	if (ma4HHandle != INVALID_HANDLE)

	{

		ArraySetAsSeries(buf4, false);
		ArraySetAsSeries(t4, false);

		c4 = CopyBuffer(ma4HHandle, 0, 0, toCopy, buf4);

		c4 = MathMin(c4, CopyTime(_Symbol, PERIOD_H4, 0, toCopy, t4));

		if (c4 <= 0)
			c4 = 0;
	}

	if (maDHandle != INVALID_HANDLE)

	{

		ArraySetAsSeries(bufD, false);
		ArraySetAsSeries(tD, false);

		cD = CopyBuffer(maDHandle, 0, 0, toCopy, bufD);

		cD = MathMin(cD, CopyTime(_Symbol, PERIOD_D1, 0, toCopy, tD));

		if (cD <= 0)
			cD = 0;
	}

	if (maMHandle != INVALID_HANDLE)

	{

		ArraySetAsSeries(bufM, false);
		ArraySetAsSeries(tM, false);

		cM = CopyBuffer(maMHandle, 0, 0, toCopy, bufM);

		cM = MathMin(cM, CopyTime(_Symbol, PERIOD_MN1, 0, toCopy, tM));

		if (cM <= 0)
			cM = 0;
	}

	//--- map each current bar (oldest->newest)

	for (int i = 0; i < rates_total; i++)

	{

		datetime tt = time[i];

		// H1

		if (c1 > 0)

		{

			int k = FindIndexByTime(t1, c1, tt);

			if (k >= 0)

			{

				if (InpInterpolate && k + 1 < c1)

				{

					double v1 = buf1[k];

					double v2 = buf1[k + 1];

					double dt = (double)(t1[k + 1] - t1[k]);

					double prog = dt > 0 ? (double)(tt - t1[k]) / dt : 0.0;

					ma1H[i] = v1 + prog * (v2 - v1);
				}

				else
					ma1H[i] = buf1[k];
			}

			else
				ma1H[i] = EMPTY_VALUE;
		}

		else
			ma1H[i] = EMPTY_VALUE;

		// H4

		if (c4 > 0)

		{

			int k = FindIndexByTime(t4, c4, tt);

			if (k >= 0)

			{

				if (InpInterpolate && k + 1 < c4)

				{

					double v1 = buf4[k];
					double v2 = buf4[k + 1];

					double dt = (double)(t4[k + 1] - t4[k]);

					double prog = dt > 0 ? (double)(tt - t4[k]) / dt : 0.0;

					ma4H[i] = v1 + prog * (v2 - v1);
				}

				else
					ma4H[i] = buf4[k];
			}

			else
				ma4H[i] = EMPTY_VALUE;
		}

		else
			ma4H[i] = EMPTY_VALUE;

		// D1

		if (cD > 0)

		{

			int k = FindIndexByTime(tD, cD, tt);

			if (k >= 0)

			{

				if (InpInterpolate && k + 1 < cD)

				{

					double v1 = bufD[k];
					double v2 = bufD[k + 1];

					double dt = (double)(tD[k + 1] - tD[k]);

					double prog = dt > 0 ? (double)(tt - tD[k]) / dt : 0.0;

					maD[i] = v1 + prog * (v2 - v1);
				}

				else
					maD[i] = bufD[k];
			}

			else
				maD[i] = EMPTY_VALUE;
		}

		else
			maD[i] = EMPTY_VALUE;

		// MN1

		if (cM > 0)

		{

			int k = FindIndexByTime(tM, cM, tt);

			if (k >= 0)

			{

				if (InpInterpolate && k + 1 < cM)

				{

					double v1 = bufM[k];
					double v2 = bufM[k + 1];

					double dt = (double)(tM[k + 1] - tM[k]);

					double prog = dt > 0 ? (double)(tt - tM[k]) / dt : 0.0;

					maM[i] = v1 + prog * (v2 - v1);
				}

				else
					maM[i] = bufM[k];
			}

			else
				maM[i] = EMPTY_VALUE;
		}

		else
			maM[i] = EMPTY_VALUE;
	}

	return (rates_total);
}
//+------------------------------------------------------------------+
