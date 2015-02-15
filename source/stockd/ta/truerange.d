module stockd.ta.truerange;

import std.range;
import stockd.defs;
import tmp = stockd.ta.templates;

/**
 * True Range
 * 
 * Ref: <a href="http://stockcharts.com/help/doku.php?id=chart_school:technical_indicators:average_true_range_a#true_range">stockcharts.com</a>
 * 
 * Wilder started with a concept called True Range (TR), which is defined as the greatest of the following:
 * Method 1: Current High less the current Low
 * Method 2: Current High less the previous Close (absolute value)
 * Method 3: Current Low less the previous Close (absolute value)
 * 
 * Absolute values are used to ensure positive numbers.
 * After all, Wilder was interested in measuring the distance between two points, not the direction.
 * If the current period's high is above the prior period's high and the low is below the prior period's low,
 * then the current period's high-low range will be used as the True Range.
 * This is an outside day that would use Method 1 to calculate the TR. This is pretty straight forward.
 * Methods 2 and 3 are used when there is a gap or an inside day. A gap occurs when the previous close is greater 
 * than the current high (signaling a potential gap down or limit move) or the previous close is lower than 
 * the current low (signaling a potential gap up or limit move).
 */
auto trueRange(R)(R input)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    return TrueRange!R(input);
}

/// dtto
struct TrueRange(R)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    private R _input;
    mixin tmp.TrueRange tr;
    
    this(R input)
    {
        this._input = input;
    }
    
    @property bool empty()
    {
        return _input.empty;
    }
    
    @property auto front()
    {
        return tr.eval(_input.front);
    }
    
    void popFront()
    {
        _input.popFront();
    }
}

unittest
{
    import std.csv;
    import std.stdio;
    import std.datetime;
    import std.math;

    writeln(">> TrueRange tests <<");

    struct Layout {double high; double low; double close;}

    auto strBars = r"48.7000;47.7900;48.1600
        48.7200;48.1400;48.6100
        48.9000;48.3900;48.7500
        48.8700;48.3700;48.6300
        48.8200;48.2400;48.7400
        49.0500;48.6350;49.0300
        49.2000;48.9400;49.0700
        49.3500;48.8600;49.3200
        49.9200;49.5000;49.9100
        50.1900;49.8700;50.1300
        50.1200;49.2000;49.5300
        49.6600;48.9000;49.5000
        49.8800;49.4300;49.7500
        50.1900;49.7250;50.0300
        50.3600;49.2600;50.3100
        50.5700;50.0900;50.5200
        50.6500;50.3000;50.4100
        50.4300;49.2100;49.3400
        49.6300;48.9800;49.3700
        50.3300;49.6100;50.2300
        50.2900;49.2000;49.2375
        50.1700;49.4300;49.9300
        49.3200;48.0800;48.4300
        48.5000;47.6400;48.1800
        48.3201;41.5500;46.5700
        46.8000;44.2833;45.4100
        47.8000;47.3100;47.7700
        48.3900;47.2000;47.7200
        48.6600;47.9000;48.6200
        48.7900;47.7301;47.8500";

    auto records = csvReader!Layout(strBars,';');
    Bar[] bars;
    foreach(r; records)
    {
        bars ~= Bar(DateTime(2010, 1, 1, 1), r.close, r.high, r.low, r.close);
    }

    double[] expected = [
        0.91000, 0.58000, 0.51000, 0.50000, 0.58000, 0.41500, 0.26000, 0.49000, 
        0.60000, 0.32000, 0.93000, 0.76000, 0.45000, 0.46500, 1.10000, 0.48000, 
        0.35000, 1.22000, 0.65000, 0.96000, 1.09000, 0.93250, 1.85000, 0.86000, 
        6.77010, 2.51670, 2.39000, 1.19000, 0.94000, 1.05990];

    auto range = trueRange(bars);
    assert(isInputRange!(typeof(range)));
    auto eval = range.array;
    assert(approxEqual(expected, eval));

    auto wrapped = inputRangeObject(trueRange(bars));
    eval = wrapped.array;
    assert(approxEqual(expected, eval));

    writeln(">> TrueRange tests OK <<");
}
