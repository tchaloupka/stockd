module stockd.ta.median;

import stockd.defs.bar;
import std.range;
import stockd.ta.templates;

/**
 * Evaluates median price for the specified period
 * 
 * median = (max + min)/2
 * 
 * Where max and min are evaluated from values within period
 */
auto median(R)(R input, ushort period = 14)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    return Median!R(input, period);
}

/// dtto
struct Median(R)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    private R _input;

    mixin MinMax!(true) min;
    mixin MinMax!(false) max;

    this(R input, ushort period = 14)
    {
        min.initialize(period);
        max.initialize(period);
        this._input = input;
    }

    @property bool empty()
    {
        return _input.empty;
    }
    
    @property auto front()
    {
        auto val = _input.front;

        return (max.eval(val.high) + min.eval(val.low))/2;
    }

    void popFront()
    {
        _input.popFront();
    }
}

unittest
{
    import std.csv;
    import std.math : approxEqual;
    import std.stdio;
    import std.datetime;

    writeln(">> Median tests <<");
    
    struct Layout {double high; double low;}
    
    auto strBars = r"127.009;125.3574
127.6159;126.1633
126.5911;124.9296
127.3472;126.0937
128.173;126.8199
128.4317;126.4817
127.3671;126.034
126.422;124.8301
126.8995;126.3921
126.8498;125.7156
125.646;124.5615
125.7156;124.5715
127.1582;125.0689
127.7154;126.8597
127.6855;126.6309
128.2228;126.8001
128.2725;126.7105
128.0934;126.8001
128.2725;126.1335
127.7353;125.9245
128.77;126.9891
129.2873;127.8148
130.0633;128.4715
129.1182;128.0641
129.2873;127.6059
128.4715;127.596
128.0934;126.999
128.6506;126.8995
129.1381;127.4865
128.6406;127.397
";
    
    auto records = csvReader!Layout(strBars,';');
    Bar[] bars;
    foreach(r; records)
    {
        bars ~= Bar(DateTime(2010, 1, 1, 1), r.high, r.high, r.low, r.low);
    }
    
    double[] expected = [126.1832,126.48665,126.27275,126.27275,126.5513,126.68065,126.68065,126.6309,126.6309,126.6309,126.4966,126.4966,125.9643,126.13845,126.13845,126.39215,126.417,126.422,126.6707,127.0985,127.34725,127.6059,127.9939,127.9939,127.9939,127.9939,128.5262,128.4814,128.4814,128.0934];

    auto range = median(bars, 7);
    assert(isInputRange!(typeof(range)));
    auto evaluated = range.array;
    assert(approxEqual(expected, evaluated));
    
    auto wrapped = inputRangeObject(median(bars, 7));
    evaluated = wrapped.array;
    assert(approxEqual(expected, evaluated));

    writeln(">> Median tests OK <<");
}

