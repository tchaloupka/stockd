module stockd.ta.macd;

import stockd.ta.templates;
import std.typecons;
import std.range;

/** 
 * Moving Average Convergence Divergence
 * 
 * Ref: <a href="http://stockcharts.com/school/doku.php?st=macd&id=chart_school:technical_indicators:moving_average_conve">stockcharts.com</a>
 * 
 * Developed by Gerald Appel in the late seventies, the Moving Average Convergence-Divergence (MACD) indicator is one 
 * of the simplest and most effective momentum indicators available. The MACD turns two trend-following indicators, 
 * moving averages, into a momentum oscillator by subtracting the longer moving average from the shorter moving average. 
 * As a result, the MACD offers the best of both worlds: trend following and momentum. 
 * The MACD fluctuates above and below the zero line as the moving averages converge, cross and diverge. 
 * Traders can look for signal line crossovers, centerline crossovers and divergences to generate signals. 
 * Because the MACD is unbounded, it is not particularly useful for identifying overbought and oversold levels.
 * 
 * Calculation:
 *  MACD Line: (12-day EMA - 26-day EMA) 
 *  Signal Line: 9-day EMA of MACD Line
 *  MACD Histogram: MACD Line - Signal Line
 * 
 * Params:
 *      fastPeriod  = EMA period for fast line
 *      slowPeriod  = EMA period for slow line
 *      smooth      = EMA period for the smoothed MACD line
 */
auto macd(R)(R input, ushort fastPeriod = 12, ushort slowPeriod = 26, ushort smooth = 9)
    if(isInputRange!R && is(ElementType!R == double))
{
    assert(fastPeriod > 0);
    assert(slowPeriod > 0);
    assert(fastPeriod < slowPeriod);
    assert(smooth > 0);

    return MACD!R(input, fastPeriod, slowPeriod, smooth);
}

/// dtto
struct MACD(R)
    if(isInputRange!R && is(ElementType!R == double))
{
    mixin Ema fast;
    mixin Ema slow;
    mixin Ema smooth;

    private R _input;
    private Tuple!(double, double, double) _cur;
    
    /**
     * Constructor
     */
    this(R input, ushort fastPeriod = 12, ushort slowPeriod = 26, ushort smoothPeriod = 9)
    {
        assert(fastPeriod > 0);
        assert(slowPeriod > 0);
        assert(fastPeriod < slowPeriod);
        assert(smoothPeriod > 0);

        this._input = input;
        fast.initialize(fastPeriod);
        slow.initialize(slowPeriod);
        smooth.initialize(smoothPeriod);

        calcNext();
    }

    @property bool empty()
    {
        return _input.empty;
    }
    
    /**
     * Evaluate next value
     * 
     * Returns tuple of:
     *      macd    - macd line
     *      signal  - smoothed macd line
     *      hist    - difference between macd and signal lines
     */
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
        if(empty) _cur = tuple(double.nan, double.nan, double.nan);
        else
        {
            auto value = _input.front;
            double f = fast.eval(value);
            double s = slow.eval(value);
            
            double macd = f - s;
            double signal = smooth.eval(macd);
            double hist = macd - signal;

            _cur = tuple(macd, signal, hist);
        }
    }
}

unittest
{
    import std.math;
    import std.stdio;
    import std.algorithm : map;

    writeln(">> MACD tests <<");
    
    double[] input     = [459.99, 448.85, 446.06, 450.81, 442.8, 448.97, 444.57, 441.4, 430.47, 420.05, 431.14, 425.66, 430.58, 431.72, 437.87, 428.43, 428.35, 432.5, 443.66, 455.72, 454.49, 452.08, 452.73, 461.91, 463.58, 461.14, 452.08, 442.66, 428.91, 429.79, 431.99, 427.72, 423.2, 426.21, 426.98, 435.69, 434.33, 429.8, 419.85, 426.24, 402.8, 392.05, 390.53, 398.67, 406.13, 405.46, 408.38, 417.2, 430.12, 442.78, 439.29, 445.52, 449.98, 460.71, 458.66, 463.84, 456.77, 452.97, 454.74, 443.86, 428.85, 434.58, 433.26, 442.93, 439.66, 441.35];
    double[] expMACD   = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.7936538462, -1.3625295858, -1.2954481111, -2.0978503247, -2.7595978992, -2.8855873627, -1.8475212907, 0.2665912965, 1.8731596685, 2.9248563828, 3.8489085781, 5.6224390867, 7.2483548683, 8.2752695039, 7.7033783815, 6.416074757, 4.2375197833, 2.5525833249, 1.3788857199, 0.1029814912, -1.2584019528, -2.0705581901, -2.6218423283, -2.3290667405, -2.1816321148, -2.4026262729, -3.3421216814, -3.5303631361, -5.5074712486, -7.8512742286, -9.7193674552, -10.422866508, -10.2601621589, -10.0692096101, -9.571919612, -8.3696334924, -6.3016357237, -3.5996815091, -1.7201483609, 0.2690032323, 2.1801732471, 4.5086378086, 6.1180201538, 7.7224305935, 8.3274538087, 8.4034411846, 8.5084063232, 7.625761844, 5.6499490829, 4.4946547649, 3.4329893617, 3.3334738536, 2.9566628561, 2.7625612158];
    double[] expSignal = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.1587307692, -0.3994905325, -0.5786820482, -0.8825157035, -1.2579321427, -1.5834631867, -1.6362748075, -1.2557015867, -0.6299293356, 0.0810278081, 0.8346039621, 1.792170987, 2.8834077632, 3.9617801114, 4.7100997654, 5.0512947637, 4.8885397676, 4.4213484791, 3.8128559272, 3.07088104, 2.2050244415, 1.3499079151, 0.5555578665, -0.0213670549, -0.4534200669, -0.8432613081, -1.3430333827, -1.7804993334, -2.5258937165, -3.5909698189, -4.8166493461, -5.9378927785, -6.8023466546, -7.4557192457, -7.878959319, -7.9770941537, -7.6420024677, -6.833538276, -5.8108602929, -4.5948875879, -3.2398754209, -1.690172775, -0.1285341892, 1.4416587673, 2.8188177756, 3.9357424574, 4.8502752306, 5.4053725533, 5.4542878592, 5.2623612403, 4.8964868646, 4.5838842624, 4.2584399811, 3.9592642281];
    double[] expHist   = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -0.6349230769, -0.9630390533, -0.7167660628, -1.2153346212, -1.5016657565, -1.302124176, -0.2112464832, 1.5222928832, 2.5030890041, 2.8438285748, 3.0143046161, 3.8302680997, 4.364947105, 4.3134893925, 2.9932786161, 1.3647799932, -0.6510199844, -1.8687651542, -2.4339702074, -2.9678995488, -3.4634263943, -3.4204661052, -3.1774001947, -2.3076996855, -1.7282120479, -1.5593649648, -1.9990882986, -1.7498638027, -2.9815775322, -4.2603044097, -4.9027181091, -4.4849737295, -3.4578155043, -2.6134903644, -1.692960293, -0.3925393388, 1.340366744, 3.2338567668, 4.090711932, 4.8638908202, 5.420048668, 6.1988105836, 6.2465543431, 6.2807718262, 5.5086360331, 4.4676987272, 3.6581310926, 2.2203892908, 0.1956612237, -0.7677064754, -1.4634975029, -1.2504104088, -1.301777125, -1.1967030123];


    auto range = macd(input, 12, 26, 9);
    assert(isInputRange!(typeof(range)));
    auto evaluated = range.array;
    assert(approxEqual(expMACD, evaluated.map!"a[0]"));
    assert(approxEqual(expSignal, evaluated.map!"a[1]"));
    assert(approxEqual(expHist, evaluated.map!"a[2]"));

    auto wrapped = inputRangeObject(macd(input, 12, 26, 9));
    evaluated = wrapped.array;
    assert(approxEqual(expMACD, evaluated.map!"a[0]"));
    assert(approxEqual(expSignal, evaluated.map!"a[1]"));
    assert(approxEqual(expHist, evaluated.map!"a[2]"));

    // repeated front access test
    range = macd(input, 12, 26, 9);
    foreach(i; 0..expMACD.length)
    {
        foreach(j; 0..10)
        {
            auto front = range.front;
            assert(approxEqual(front[0], expMACD[i]));
            assert(approxEqual(front[1], expSignal[i]));
            assert(approxEqual(front[2], expHist[i]));
        }
        range.popFront();
    }

    writeln(">> MACD tests OK <<");
}
