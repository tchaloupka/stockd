module stockd.ta.tp;

import stockd.defs.bar;

/**
 * Typical Price
 * 
 * Simple indicator calculated as:
 * TP = (High + Low + Close)/3
 * 
 * Opposite to Average price, the Open price is ignored
 */
class TP
{
    this()
    {
        // Constructor code
    }

    pure nothrow double Add(Bar value)
    {
        return (value.high + value.low + value.close)/3;
    }
    
    static void evaluate(const ref Bar[] input, ref double[] output)
    {
        assert(input != null);
        assert(output != null);
        
        Bar iBar;
        for(size_t i = 0; i<input.length; i++)
        {
            iBar = input[i];
            output[i] = (iBar.high + iBar.low + iBar.close)/3;
        }
    }
}

unittest
{
    import std.datetime;
    import std.stdio;
    import std.math;
    
    Bar[] bars = 
    [
        Bar(DateTime(2000, 1, 1), 2, 4, 1, 3, 100),
        Bar(DateTime(2000, 1, 1), 10, 20, 5, 15, 100),
        Bar(DateTime(2000, 1, 1), 0.1, 1, 0.1, 0.6, 100)
    ];
    
    double[] expected = [2.666667, 13.33333, 0.566666];
    double[] evaluated = new double[3];
    
    TP.evaluate(bars, evaluated);
    assert(approxEqual(expected, evaluated));
    
    auto tp = new TP();
    for(int i=0; i<bars.length; i++)
    {
        assert(approxEqual(expected[i], tp.Add(bars[i])));
    }
}