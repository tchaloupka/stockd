module stockd.ta.avg;

import stockd.defs.bar;

/**
 * Evaluates average of all bar prices (OHLC)
 */
class Avg
{
    this()
    {
        // Constructor code
    }

    pure nothrow double Add(Bar value)
    {
        return (value.open + value.high + value.low + value.close)*0.25;
    }

    static void evaluate(const ref Bar[] input, ref double[] output)
    {
        assert(input != null);
        assert(output != null);

        Bar iBar;
        for(size_t i = 0; i<input.length; i++)
        {
            iBar = input[i];
            output[i] = (iBar.open + iBar.high + iBar.low + iBar.close)*0.25;
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

    double[] expected = [2.5, 12.5, 0.45];
    double[] evaluated = new double[3];

    Avg.evaluate(bars, evaluated);
    assert(approxEqual(expected, evaluated));

    auto avg = new Avg();
    for(int i=0; i<bars.length; i++)
    {
        assert(approxEqual(expected[i], avg.Add(bars[i])));
    }
}