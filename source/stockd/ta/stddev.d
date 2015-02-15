module stockd.ta.stddev;

import std.range;
import std.math;
import tmp = stockd.ta.templates;

/**
 * Standard Deviation (Volatility)
 * 
 * Ref: <a href="http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:standard_deviation_v">stockcharts.com</a>
 * 
 * Introduction:
 * 
 * Standard deviation is a statistical term that measures the amount of variability or dispersion around an average. 
 * Standard deviation is also a measure of volatility. Generally speaking, dispersion is the difference between the actual value 
 * and the average value. The larger this dispersion or variability is, the higher the standard deviation. The smaller this 
 * dispersion or variability is, the lower the standard deviation. Chartists can use the standard deviation to measure expected 
 * risk and determine the significance of certain price movements.
 * 
 * Calculation:
 * 
 *      Calculate the average (mean) price for the number of periods or observations.
 *      Determine each period's deviation (close less average price).
 *      Square each period's deviation.
 *      Sum the squared deviations.
 *      Divide this sum by the number of observations.
 *      The standard deviation is then equal to the square root of that number.
 */
auto stddev(R)(R input, ushort period = 14)
    if(isInputRange!R && is(ElementType!R == double))
{
    return StdDev!R(input, period);
}

struct StdDev(R)
    if(isInputRange!R && is(ElementType!R == double))
{
    private R input;
    mixin tmp.StdDev stdd;

    this(R input, ushort period = 14)
    {
        stdd.initialize(period);
        this.input = input;
    }

    @property bool empty()
    {
        return input.empty;
    }
    
    @property auto front()
    {
        return stdd.eval(input.front);
    }

    void popFront()
    {
        input.popFront();
    }
}

unittest
{
    import std.stdio;

    writeln(">> StdDev tests <<");
    
    ushort period = 20;
    double[] input    = [86.15570,89.08670,88.78290,90.32280,89.06710,91.14530,89.43970,89.17500,86.93020,87.67520,86.95960,89.42990,89.32210,88.72410,87.44970,87.26340,89.49850,87.90060,89.12600,90.70430,92.90010,92.97840,91.80210,92.66470,92.68430,92.30210,92.77250,92.53730,92.94900,93.20390,91.06690,89.83180,89.74350,90.39940,90.73870,88.01770,88.08670,88.84390,90.77810,90.54160,91.38940,90.65000];
    double[] expected = [0.00000,1.46550,1.31594,1.51759,1.37089,1.55182,1.44181,1.34873,1.44992,1.42379,1.45471,1.41097,1.36635,1.31664,1.31146,1.31308,1.29295,1.26709,1.23944,1.29196,1.45205,1.68643,1.77175,1.90207,2.01989,2.07655,2.17656,2.24192,2.20236,2.19219,2.02181,2.00941,1.99508,1.93604,1.76013,1.68275,1.77913,1.70406,1.64200,1.64509,1.60133,1.54916];
    
    auto range = stddev(input, 20);
    assert(isInputRange!(typeof(range)));
    auto evaluated = range.array;
    assert(approxEqual(expected, evaluated));
    
    auto wrapped = inputRangeObject(stddev(input, 20));
    evaluated = wrapped.array;
    assert(approxEqual(expected, evaluated));

    writeln(">> StdDev tests OK <<");
}