module stockd.ta.min;

import std.range;
import stockd.ta.templates;

/**
 * Evaluates the minimal value for the specified time period
 */
auto min(R)(R input, ushort period = 14)
    if(isInputRange!R && is(ElementType!R == double))
{
    return Min!R(input, period);
}

/// dtto
struct Min(R)
    if(isInputRange!R && is(ElementType!R == double))
{
    mixin MinMax!(true) min;
    private R _input;

    this(R input, ushort period = 14)
    {
        min.initialize(period);
        this._input = input;
    }

    @property bool empty()
    {
        return _input.empty;
    }
    
    @property auto front()
    {
        return min.eval(_input.front);
    }

    void popFront()
    {
        _input.popFront();
    }
}

unittest
{
    import std.stdio;
    import std.math : approxEqual;

    writeln(">> Min tests <<");

    double[] input    = [1,2,3,4,5,2,3,4,5,3,4,5,6];
    double[] expected = [1,1,1,1,2,2,2,2,2,3,3,3,3];

    auto range = min(input, 4);
    assert(isInputRange!(typeof(range)));
    auto evaluated = range.array;
    assert(approxEqual(expected, evaluated));
    
    auto wrapped = inputRangeObject(min(input, 4));
    evaluated = wrapped.array;
    assert(approxEqual(expected, evaluated));

    writeln(">> Min tests OK <<");
}
