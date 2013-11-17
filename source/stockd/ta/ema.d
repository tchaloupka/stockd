module stockd.ta.ema;

/** 
 * A type of moving average that is similar to a simple moving average, except that more weight
 * is given to the latest data. 
 * The exponential moving average is also known as "exponentially weighted moving average".
 */
class Ema
{
    private double m1, m2;
    private bool hasVal, sma;
    private ushort idx, period;
    private double lastVal = 0;

    /**
     * Params:
     *      period  = period EMA is calculated for
     *      sma     = use SMA instead of EMA for 0..period-1 values
     */
    this(ushort period = 12, bool sma = true)
    {
        assert(period > 0);

        this.m1 = 2.0/(1 + period);
        this.m2 = 1 - this.m1;
        this.period = period;
        this.sma = sma;
    }

    /// Evaluate next value
    double add(double value)
    {
        if(!hasVal)
        {
            if(sma)
            {
                lastVal += value;
                idx++;
                
                if(idx == period) 
                {
                    hasVal = true;
                    lastVal = lastVal / idx;
                    return lastVal;
                }
                
                return lastVal / idx;
            }
            else
            {
                lastVal = value;
                hasVal = true;
                
                return value;
            }
        }
        
        lastVal = value * m1 + lastVal * m2; 
        
        return lastVal;
    }

    /// Evaluate EMA for the whole input array
    static void evaluate(const ref double[] input, ushort period, ref double[] output, bool sma = true)
    {
        assert(input != null);
        assert(output != null);
        assert(input.length == output.length);
        assert(input.length > 0);
        assert(period > 0);
        
        double  m1   = 2.0/(1 + period);
        double  m2   = 1-m1;
        double  prev = 0;
        ulong   i    = 0;

        if(sma == true)
        {
            for(; i < period; i++)
            {
                prev += input[i];
                output[i] = prev / (i + 1);
            }
            prev /= period;
        }
        else
        {
            prev = input[0];
            output[i++] = prev;
        }
        
        for(; i<input.length; i++)
        {
            prev = input[i] * m1 + prev * m2;
            output[i] = prev;
        }
    }
}

unittest
{
    import std.math;
    import std.stdio;

    ushort period = 10;
    double[] input       = [22.27340, 22.19400, 22.08470, 22.17410, 22.18400, 22.13440, 22.23370, 22.43230, 22.24360, 22.29330, 22.15420, 22.39260, 22.38160, 22.61090, 23.35580, 24.05190, 23.75300, 23.83240, 23.95160, 23.63380, 23.82250, 23.87220, 23.65370, 23.18700, 23.09760, 23.32600, 22.68050, 23.09760, 22.40250, 22.17250];
    double[] expectedSMA = [22.27340, 22.23370, 22.18403, 22.18155, 22.18204, 22.17410, 22.18261, 22.21383, 22.21713, 22.22475, 22.21192, 22.24477, 22.26965, 22.33170, 22.51790, 22.79681, 22.97066, 23.12734, 23.27721, 23.34204, 23.42940, 23.50991, 23.53605, 23.47259, 23.40441, 23.39015, 23.26112, 23.23139, 23.08068, 22.91556];
    double[] expectedEMA = [22.27340, 22.25896, 22.22728, 22.21761, 22.21150, 22.19748, 22.20407, 22.24556, 22.24521, 22.25395, 22.23581, 22.26432, 22.28564, 22.34478, 22.52860, 22.80557, 22.97783, 23.13320, 23.28200, 23.34597, 23.43261, 23.51253, 23.53820, 23.47435, 23.40585, 23.39133, 23.26209, 23.23218, 23.08133, 22.91609];
    double[] evaluated = new double[input.length];

    Ema.evaluate(input, period, evaluated);
    assert(approxEqual(expectedSMA, evaluated));

    Ema.evaluate(input, period, evaluated, false);
    assert(approxEqual(expectedEMA, evaluated));
    
    auto emaS = new Ema(period);
    auto emaE = new Ema(period, false);
    for(int i=0; i<input.length; i++)
    {
        assert(approxEqual(expectedSMA[i], emaS.add(input[i])));
        assert(approxEqual(expectedEMA[i], emaE.add(input[i])));
    }
}

