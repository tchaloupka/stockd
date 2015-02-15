module stockd.ta.curday_ohl;

import std.datetime;
import std.range;
import std.typecons : tuple;
import stockd.defs.bar;
import stockd.defs.session;

auto curDayOHL(R)(R input, TimeOfDay sessionStart)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    return CurrentDayOHL!R(input, sessionStart);
}

/**
 * Indicates che current trading session day open, highest and lowest price to see the potencial price movement
 * 
 * Works only for a intraday data!!
 */
struct CurrentDayOHL(R)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    private TimeOfDay sessionStart;
    private DateTime lastTime = DateTime.min();
    private double curOpen;
    private double curHigh;
    private double curLow;
    private R input;

    /**
     * Params:
     *      sessionStart - time in UTC at whitch the trading session starts
     */
    this(R input, TimeOfDay sessionStart)
    {
        this.sessionStart = sessionStart;
        this.input = input;
    }

    @property bool empty()
    {
        return input.empty;
    }
    
    @property auto front()
    {
        auto value = input.front;

        if(isNextSession(lastTime, value.time, sessionStart))
        {
            curOpen = value.open;
            curHigh = value.high;
            curLow = value.low;
        }
        else
        {
            if(curHigh < value.high) curHigh = value.high;
            if(curLow > value.low) curLow = value.low;
        }
        
        return tuple(curOpen, curHigh, curLow);
    }

    void popFront()
    {
        input.popFront();
    }
}

unittest
{
    import std.stdio;
    import std.algorithm : map;
    import std.math;

    writeln(">> Current Day OHL tests <<");

    auto sessionStart = TimeOfDay(9, 0, 0);

    Bar[] bars = 
    [
        Bar(DateTime(2000, 1, 1, 8, 0, 0), 2, 3, 1, 2, 100),
        Bar(DateTime(2000, 1, 1, 8, 30, 0), 2.5, 5, 2, 3, 100),
        Bar(DateTime(2000, 1, 1, 9, 0, 0), 3, 3, 2, 2, 100),
        Bar(DateTime(2000, 1, 1, 9, 30, 0), 7, 9, 7, 8, 100),
        Bar(DateTime(2000, 1, 1, 10, 30, 0), 8, 12, 1, 11, 100)
    ];

    double[] expOpen = [2, 2, 3, 3, 3];
    double[] expHigh = [3, 5, 3, 9, 12];
    double[] expLow = [1, 1, 2, 2, 1];

    auto range = curDayOHL(bars, sessionStart);
    assert(isInputRange!(typeof(range)));
    auto evaluated = range.array;
    assert(approxEqual(expOpen, evaluated.map!"a[0]"));
    assert(approxEqual(expHigh, evaluated.map!"a[1]"));
    assert(approxEqual(expLow, evaluated.map!"a[2]"));
    
    auto wrapped = inputRangeObject(curDayOHL(bars, sessionStart));
    evaluated = wrapped.array;
    assert(approxEqual(expOpen, evaluated.map!"a[0]"));
    assert(approxEqual(expHigh, evaluated.map!"a[1]"));
    assert(approxEqual(expLow, evaluated.map!"a[2]"));

    writeln(">> Current Day OHL tests OK <<");
}