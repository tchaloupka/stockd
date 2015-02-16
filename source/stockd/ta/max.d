module stockd.ta.max;

import std.range;
import stockd.ta.templates;

/** 
 * Evaluates the maximum value of the specified period
 */
auto max(R)(R input, ushort period = 14)
    if(isInputRange!R && is(ElementType!R == double))
{
    return Max!R(input, period);
}

/// dtto
struct Max(R)
    if(isInputRange!R && is(ElementType!R == double))
{
    mixin MinMax!(false) max;
    private R _input;
    private double _cur;

    this(R input, ushort period = 14)
    {
        max.initialize(period);
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

    private void calcNext() pure nothrow @nogc
    {
        if(empty) _cur = double.nan;
        else _cur = max.eval(_input.front);
    }
}

unittest
{
    import std.stdio;
    import std.math : approxEqual;

    writeln(">> Max tests <<");

    double[] input    = [1,2,3,4,5,9,3,4,5,3,4,5,6];
    double[] expected = [1,2,3,4,5,9,9,9,9,5,5,5,6];

    auto range = max(input, 4);
    assert(isInputRange!(typeof(range)));
    auto evaluated = range.array;
    assert(approxEqual(expected, evaluated));
    
    auto wrapped = inputRangeObject(max(input, 4));
    evaluated = wrapped.array;
    assert(approxEqual(expected, evaluated));

    // repeated front access test
    range = max(input, 4);
    foreach(i; 0..expected.length)
    {
        foreach(j; 0..10)
        {
            assert(approxEqual(range.front, expected[i]));
        }
        range.popFront();
    }

    writeln(">> Max tests OK <<");
}
