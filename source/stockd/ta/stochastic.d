module stockd.ta.stochastic;

import std.range;
import std.typecons;
import stockd.defs.bar;
import stockd.ta.templates;

/**
 * Stochastic Oscillator
 * 
 * Ref: <a href="http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:stochastic_oscillato">stockcharts.com</a>
 * 
 * Developed by George C. Lane in the late 1950s, the Stochastic Oscillator is a momentum indicator that shows the location of the close 
 * relative to the high-low range over a set number of periods. According to an interview with Lane, the Stochastic Oscillator 
 * "doesn't follow price, it doesn't follow volume or anything like that. It follows the speed or the momentum of price. 
 * As a rule, the momentum changes direction before price." As such, bullish and bearish divergences in the Stochastic Oscillator can be 
 * used to foreshadow reversals. This was the first, and most important, signal that Lane identified. 
 * Lane also used this oscillator to identify bull and bear set-ups to anticipate a future reversal. 
 * Because the Stochastic Oscillator is range bound, is also useful for identifying overbought and oversold levels.
 * 
 * Calculation:
 *      %K = (Current Close - Lowest Low)/(Highest High - Lowest Low) * 100
 *      %D = 3-day SMA of %K
 * 
 * Where:
 *      Lowest Low = lowest low for the look-back period
 *      Highest High = highest high for the look-back period
 *      %K is multiplied by 100 to move the decimal point two places
 * 
 * Full Stochastic Oscillator:
 *      Full %K = Fast %K smoothed with X-period SMA
 *      Full %D = X-period SMA of Full %K
 */
auto stochastic(R)(R input, ushort period = 14, ushort kSmooth = 3, ushort dSmooth = 7)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    return Stochastic!R(input, period, kSmooth, dSmooth);
}

struct Stochastic(R)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    private R _input;
    private double _prevFastK = 50;
	private Tuple!(double, double) _cur;

    mixin MinMax!false maxeval;
    mixin MinMax!true mineval;
    mixin Sma kSmooth;
    mixin Sma dSmooth;

    this(R input, ushort period = 14, ushort kSmoothPeriod = 3, ushort dSmoothPeriod = 7)
    {
        assert(period > 0);
        assert(kSmoothPeriod > 0);
        assert(dSmoothPeriod > 0);

        mineval.initialize(period);
        maxeval.initialize(period);
        kSmooth.initialize(kSmoothPeriod);
        dSmooth.initialize(dSmoothPeriod);

        this._input = input;
		calcNext();
    }

    @property bool empty()
    {
        return _input.empty;
    }
    
    @property auto front()
    {
		return _cur;
    }

    void popFront()
    {
        _input.popFront();
		calcNext();
    }

	private void calcNext()
	{
		if(empty) _cur = tuple(double.nan, double.nan);
		else
		{
			auto val = _input.front;
			double min = mineval.eval(val.low);
			double max = maxeval.eval(val.high);
			
			double nom = val.close - min;
			double den = max - min;
			
			_prevFastK = den < 0.000000000001 ? _prevFastK : 100 * nom / den;
			
			double k = kSmooth.eval(_prevFastK);
			double d = dSmooth.eval(k);
			
			_cur = tuple(k, d);
		}
	}
}

unittest
{
    import std.csv;
    import std.math : approxEqual;
    import std.stdio;
    import std.datetime;
    import std.algorithm : map;

    writeln(">> Stochastic tests <<");
    
    struct Layout {double high; double low; double close;}
    
    auto strBars = r"127.00900;125.35740;126.81000
127.61590;126.16330;126.35000
126.59110;124.92960;126.33000
127.34720;126.09370;126.10000
128.17300;126.81990;126.90000
128.43170;126.48170;127.00000
127.36710;126.03400;126.20000
126.42200;124.83010;125.00000
126.89950;126.39210;126.50000
126.84980;125.71560;126.00000
125.64600;124.56150;125.00000
125.71560;124.57150;125.00000
127.15820;125.06890;126.00000
127.71540;126.85970;127.28760
127.68550;126.63090;127.17810
128.22280;126.80010;128.01380
128.27250;126.71050;127.10850
128.09340;126.80010;127.72530
128.27250;126.13350;127.05870
127.73530;125.92450;127.32730
128.77000;126.98910;128.71030
129.28730;127.81480;127.87450
130.06330;128.47150;128.58090
129.11820;128.06410;128.60080
129.28730;127.60590;127.93420
128.47150;127.59600;128.11330
128.09340;126.99900;127.59600
128.65060;126.89950;127.59600
129.13810;127.48650;128.69040
128.64060;127.39700;128.27250";
    
    auto records = csvReader!Layout(strBars,';');
    Bar[] bars;
    foreach(r; records)
    {
        bars ~= Bar(DateTime(2010, 1, 1, 1), r.close, r.high, r.low, r.close);
    }

    double[] expectedK = [87.95108, 65.95030, 61.34393, 46.54998, 52.15049, 54.47970, 52.04842, 33.37051, 29.11941, 27.85521, 30.05948, 18.38104, 19.94298, 39.64567, 58.40525, 75.74975, 74.20719, 78.92012, 70.69402, 73.60043, 79.21167, 81.07192, 80.58069, 72.19280, 69.23506, 65.20178, 54.19122, 47.24283, 49.20025, 54.64869];
    double[] expectedD = [87.95108, 76.95069, 71.74844, 65.44882, 62.78915, 61.40425, 60.06770, 52.27048, 47.00892, 42.22482, 39.86903, 35.04483, 30.11101, 28.33919, 31.91558, 38.57705, 45.19877, 52.17886, 59.65214, 67.31749, 72.96978, 76.20787, 76.89801, 76.61024, 75.22666, 74.44205, 71.66931, 67.10233, 62.54923, 58.84466];
    
    auto range = stochastic(bars, 14, 3, 7);
    assert(isInputRange!(typeof(range)));
    auto evaluated = range.array;
    assert(approxEqual(expectedK, evaluated.map!"a[0]"));
    assert(approxEqual(expectedD, evaluated.map!"a[1]"));
    
    auto wrapped = inputRangeObject(stochastic(bars, 14, 3, 7));
    evaluated = wrapped.array;
    assert(approxEqual(expectedK, evaluated.map!"a[0]"));
    assert(approxEqual(expectedD, evaluated.map!"a[1]"));

	// repeated front access test
	range = stochastic(bars, 14, 3, 7);
	foreach(i; 0..expectedK.length)
	{
		foreach(j; 0..10)
		{
			auto front = range.front;
			assert(approxEqual(front[0], expectedK[i]));
			assert(approxEqual(front[1], expectedD[i]));
		}
		range.popFront();
	}

    writeln(">> Stochastic tests OK <<");
}
