module stockd.ta.heikenashi;

import stockd.defs.bar;
import std.range;

/**
 * Heikin-Ashi Price Bars
 * 
 * Ref: <a href="http://stockcharts.com/school/doku.php?st=heiken+ashi&id=chart_school:chart_analysis:heikin_ashi">stockcharts.com</a>
 * 
 * Heikin-Ashi Candlesticks are an offshoot from Japanese candlesticks. Heikin-Ashi Candlesticks use the open-close data from the prior period 
 * and the open-high-low-close data from the current period to create a combo candlestick. The resulting candlestick filters out some noise in 
 * an effort to better capture the trend. In Japanese, Heikin means "average" and "ashi" means "pace" (EUDict.com). Taken together, 
 * Heikin-Ashi represents the average-pace of prices. Heikin-Ashi Candlesticks are not used like normal candlesticks. Dozens of bullish or bearish 
 * reversal patterns consisting of 1-3 candlesticks are not to be found. Instead, these candlesticks can be used to identify trending periods, 
 * potential reversal points and classic technical analysis patterns.
 * 
 * HaClose = (Open+High+Low+Close)/4
 *      = the average price of the current bar
 * HaOpen = [HaOpen(previous bar) + Close(previous bar)]/2
 *      = the midpoint of the previous bar
 * HaHigh = Max(High, HaOpen, HaClose)
 *      = the highest value in the range
 * HaLow = Min(Low, HaOpen, HaClose)
 *      = the lowest value in the range 
 */
auto heikenAshi(R)(R input)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    return HeikenAshi!R(input);
}

/// dtto
struct HeikenAshi(R)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    enum evalNext = `
        _close = (cur.open + cur.high + cur.low + cur.close) * 0.25;
        _front = Bar(
            cur.time,
            _open = ((_front.open + _front.close) * 0.5),
            max(cur.high, _open, _close),
            min(cur.low, _open, _close),
            _close,
            cur.volume);`;

    R _input;
    private Bar _front;
    private double _open, _close;
    
    this(R input)
    {
        this._input = input;

        auto first = input.front;

        _front = Bar(
            first.time,
            (first.open + first.close) * 0.5,
            first.high,
            first.low,
            (first.open + first.high + first.low + first.close) * 0.25,
            first.volume);
    }
    
    int opApply(scope int delegate(ref Bar) func)
    {
        import std.algorithm : max, min;

        int result;
        Bar _front = this._front;
        double _open, _close;

        //send first
        _input.popFront();
        result = func(_front);
        if(result) return result;
        
        foreach(ref cur; _input)
        {
            mixin(evalNext);
            result = func(_front);
            if(result) break;
        }
        return result;
    }
    
    @property bool empty()
    {
        return _input.empty;
    }
    
    @property auto front()
    {
        return _front;
    }
    
    void popFront()
    {
        import std.algorithm : max, min;

        _input.popFront();

        if(empty) return;
        
        auto cur = _input.front(); //cache it
        
        mixin(evalNext);
    }
}

unittest
{
    import std.stdio;
    writeln(">> HeikenAshi tests <<");

    Bar[] data = 
    [
        bar!"20000101;58.67;58.82;57.03;57.73;100",
        bar!"20000101;57.46;57.72;56.21;56.27;100",
        bar!"20000101;56.37;56.88;55.35;56.81;100"
    ];

    Bar[] expected = 
    [
        bar!"20000101;58.2;58.82;57.03;58.0625;100",
        bar!"20000101;58.13125;58.13125;56.21;56.915;100",
        bar!"20000101;57.523125;57.523125;55.35;56.3525;100"
    ];

    auto range = heikenAshi(data);
    assert(isInputRange!(typeof(range)));
    auto eval = range.array;
    assert(equal(expected, eval));
    
    auto wrapped = inputRangeObject(heikenAshi(data));
    eval = wrapped.array;
    assert(equal(expected, eval));

    writeln(">> HeikenAshi tests OK <<");
}