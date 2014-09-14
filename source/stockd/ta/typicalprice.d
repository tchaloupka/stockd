module stockd.ta.typicalprice;

import stockd.defs.bar;
import std.range;

/**
 * Typical Price
 * 
 * Simple indicator calculated as:
 * TypicalPrice = (High + Low + Close)/3
 * 
 * Opposite to Average price, the Open price is ignored
 */
auto typicalPrice(R)(R input)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    return TypicalPrice!R(input);
}

struct TypicalPrice(R)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    R _input;
    
    this(R input)
    {
        this._input = input;
    }
    
    int opApply(scope int delegate(double) func)
    {
        int result;

        foreach(ref bar; _input)
        {
            result = func((bar.high + bar.low + bar.close)/3);
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
        return (_input.front.high + _input.front.low + _input.front.close)/3;
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
    
    Bar[] bars = 
    [
        bar!"20000101;2;4;1;3;100",
        bar!"20000101;10;20;5;15;100",
        bar!"20000101;0.1;1;0.1;0.6;100"
    ];
    
    double[] expected = [2.666667, 13.33333, 0.566666];
    auto range = typicalPrice(bars);
    assert(isInputRange!(typeof(range)));
    double[] evaluated = range.array;
    assert(approxEqual(expected, evaluated));

    auto wrapped = inputRangeObject(typicalPrice(bars));
    evaluated = wrapped.array;
    assert(approxEqual(expected, evaluated));
}
