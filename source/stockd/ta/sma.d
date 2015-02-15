module stockd.ta.sma;

import std.range;
import tmp = stockd.ta.templates;

/** 
 * Simple moving average computed over a specified period of time
 */
auto sma(R)(R input, ushort period = 12)
    if(isInputRange!R && is(ElementType!R == double))
{
    return Sma!R(input, period);
}

/// dtto
struct Sma(R)
    if(isInputRange!R && is(ElementType!R == double))
{
    private R _input;
    mixin tmp.Sma sma;
    
    /**
     * Params:
     *      period  = period SMA is calculated for
     */
    this(R input, ushort period = 12)
    {
        sma.initialize(period);
        this._input = input;
    }
    
    @property bool empty()
    {
        return _input.empty;
    }
    
    @property auto front()
    {
        return sma.eval(_input.front);
    }
    
    void popFront()
    {
        _input.popFront();
    }
}

unittest
{
    import std.math : approxEqual;
    import std.stdio;

    writeln(">> SMA tests <<");
    
    double[] input    = [22.27340, 22.19400, 22.08470, 22.17410, 22.18400, 22.13440, 22.23370, 22.43230, 22.24360, 22.29330, 22.15420, 22.39260, 22.38160, 22.61090, 23.35580, 24.05190, 23.75300, 23.83240, 23.95160, 23.63380, 23.82250, 23.87220, 23.65370, 23.18700, 23.09760, 23.32600, 22.68050, 23.09760, 22.40250, 22.17250];
    double[] expected = [22.27340, 22.23370, 22.18403, 22.18155, 22.18204, 22.17410, 22.18261, 22.21383, 22.21713, 22.22475, 22.21283, 22.23269, 22.26238, 22.30606, 22.42324, 22.61499, 22.76692, 22.90693, 23.07773, 23.21178, 23.37861, 23.52657, 23.65378, 23.71139, 23.68557, 23.61298, 23.50573, 23.43225, 23.27734, 23.13121];

    auto range = sma(input, 10);
    assert(isInputRange!(typeof(range)));
    double[] evaluated = range.array;
    assert(approxEqual(expected, evaluated));
    
    auto wrapped = inputRangeObject(sma(input, 10));
    evaluated = wrapped.array;
    assert(approxEqual(expected, evaluated));

    writeln(">> SMA tests OK <<");
}

