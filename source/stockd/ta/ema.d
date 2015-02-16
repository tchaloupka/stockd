module stockd.ta.ema;

import std.range;
import tmp = stockd.ta.templates;

/** 
 * A type of moving average that is similar to a simple moving average, except that more weight
 * is given to the latest data. 
 * The exponential moving average is also known as "exponentially weighted moving average".
 * Params:
 *      period  = period EMA is calculated for
 *      sma     = use SMA instead of EMA for 0..period-1 values
 */
auto ema(R, bool sma = true)(R input, ushort period = 12)
    if(isInputRange!R && is(ElementType!R == double))
{
    return Ema!(R, sma)(input, period);
}

/// dtto
struct Ema(R, bool sma = true)
    if(isInputRange!R && is(ElementType!R == double))
{
    mixin tmp.Ema!(sma) ema;
    private R _input;
    private double _cur;

    /**
     * Params:
     *      period  = period EMA is calculated for
     *      sma     = use SMA instead of EMA for 0..period-1 values
     */
    this(R input, ushort period = 12)
    {
        ema.initialize(period);
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
        if(empty) _cur = double.nan;
        else
        {
            _cur = ema.eval(_input.front);
        }
    }
}

unittest
{
    import std.math;
    import std.stdio;

    writeln(">> EMA tests <<");

    double[] input       = [22.27340, 22.19400, 22.08470, 22.17410, 22.18400, 22.13440, 22.23370, 22.43230, 22.24360, 22.29330, 22.15420, 22.39260, 22.38160, 22.61090, 23.35580, 24.05190, 23.75300, 23.83240, 23.95160, 23.63380, 23.82250, 23.87220, 23.65370, 23.18700, 23.09760, 23.32600, 22.68050, 23.09760, 22.40250, 22.17250];
    double[] expectedSMA = [22.27340, 22.23370, 22.18403, 22.18155, 22.18204, 22.17410, 22.18261, 22.21383, 22.21713, 22.22475, 22.21192, 22.24477, 22.26965, 22.33170, 22.51790, 22.79681, 22.97066, 23.12734, 23.27721, 23.34204, 23.42940, 23.50991, 23.53605, 23.47259, 23.40441, 23.39015, 23.26112, 23.23139, 23.08068, 22.91556];
    double[] expectedEMA = [22.27340, 22.25896, 22.22728, 22.21761, 22.21150, 22.19748, 22.20407, 22.24556, 22.24521, 22.25395, 22.23581, 22.26432, 22.28564, 22.34478, 22.52860, 22.80557, 22.97783, 23.13320, 23.28200, 23.34597, 23.43261, 23.51253, 23.53820, 23.47435, 23.40585, 23.39133, 23.26209, 23.23218, 23.08133, 22.91609];

    auto range = ema(input, 10);
    assert(isInputRange!(typeof(range)));
    double[] evaluated = range.array;
    assert(approxEqual(expectedSMA, evaluated));

    auto range2 = ema!(double[], false)(input, 10);
    assert(isInputRange!(typeof(range2)));
    evaluated = range2.array;
    assert(approxEqual(expectedEMA, evaluated));
    
    auto wrapped = inputRangeObject(ema(input, 10));
    evaluated = wrapped.array;
    assert(approxEqual(expectedSMA, evaluated));

    // repeated front access test
    range = ema(input, 10);
    foreach(i; 0..expectedSMA.length)
    {
        foreach(j; 0..10)
        {
            assert(approxEqual(range.front, expectedSMA[i]));
        }
        range.popFront();
    }

    writeln(">> EMA tests OK <<");
}

