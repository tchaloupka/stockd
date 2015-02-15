module stockd.ta.avg;

import std.range;
import stockd.defs.bar;


/// Evaluates average of all bar prices (OHLC)
auto average(R)(R input)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    return Average!R(input);
}

/// dtto
struct Average(R)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    R _input;
    
    this(R input)
    {
        this._input = input;
    }
    
//    int opApply(scope int delegate(double) func)
//    {
//        int result;
//        
//        foreach(ref cur; _input)
//        {
//            result = func((cur.open + cur.high + cur.low + cur.close)*0.25);
//            if(result) break;
//        }
//        return result;
//    }
    
    @property bool empty()
    {
        return _input.empty;
    }
    
    @property auto front()
    {
        auto cur = _input.front;
        return (cur.open + cur.high + cur.low + cur.close)*0.25;
    }
    
    void popFront()
    {
        _input.popFront();
    }
}

unittest
{
    import std.datetime;
    import std.stdio;
    import std.math;

    writeln(">> AVG tests <<");

    Bar[] bars = 
    [
        bar!"20000101;2;4;1;3;100",
        bar!"20000101;10;20;5;15;100",
        bar!"20000101;0.1;1;0.1;0.6;100"
    ];
    
    double[] expected = [2.5, 12.5, 0.45];
    auto range = average(bars);
    assert(isInputRange!(typeof(range)));
    double[] evaluated = range.array;
    assert(approxEqual(expected, evaluated));
    
    auto wrapped = inputRangeObject(average(bars));
    evaluated = wrapped.array;
    assert(approxEqual(expected, evaluated));

    writeln(">> AVG tests OK <<");
}