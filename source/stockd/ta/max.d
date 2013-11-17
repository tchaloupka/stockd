module stockd.ta.max;

import std.stdio;

/** 
 * Evaluates the maximum value of the specified period
 */
class Max
{
    private ushort period;
    private ushort idx;
    private bool isBuffFull;
    private double max = int.min;
    private double[] buffer;

    this(ushort period = 14)
    {
        assert(period > 0);

        this.period = period;
        this.buffer = new double[period];
    }

    /// Add next value, returns current max for the period
    double add(double value)
    {
        bool genMax = false;
        if (isBuffFull)
        {
            if (max == buffer[idx]) genMax = true;
            else if (value > max) max = value;
        }
        else
        {
            if (value > max) max = value;
        }
        
        buffer[idx++] = value;
        if (idx == period)
        {
            isBuffFull = true;
            idx = 0;
        }
        
        if (genMax == true)
        {
            max = buffer[0];
            for (ushort i = 1; i < period; i++)
            {
                if (buffer[i] > max) max = buffer[i];
            }
        }
        
        return max;
    }

    /// Evaluates max value for the whole input array
    static void evaluate(const ref double[] input, ushort period, ref double[] output)
    {
        assert(input != null);
        assert(output != null);
        assert(input.length == output.length);
        assert(input.length > 0);
        assert(period > 0);
        
        double max = int.min, tmp;
        long trailingIdx = 0 - (period - 1);
        long today = 0;
        long maxIdx = -1;
        long i;
        long length = input.length;
        
        while (today < length)
        {
            tmp = input[today];
            
            if (maxIdx < trailingIdx)
            {
                maxIdx = trailingIdx;
                max = input[maxIdx];
                i = maxIdx;
                while (++i <= today)
                {
                    tmp = input[i];
                    if (tmp >= max)
                    {
                        max = tmp;
                        maxIdx = i;
                    }
                }
            }
            else if (tmp >= max)
            {
                max = tmp;
                maxIdx = today;
            }
            
            output[today++] = max;
            trailingIdx++;
        }
    }
}

unittest
{
    ushort period = 4;
    double[] input    = [1,2,3,4,5,9,3,4,5,3,4,5,6];
    double[] expected = [1,2,3,4,5,9,9,9,9,5,5,5,6];
    double[] evaluated = new double[input.length];

    Max.evaluate(input, period, evaluated);
    assert(evaluated == expected);
    
    auto m = new Max(period);
    for(int i=0; i<input.length; i++)
    {
        assert(expected[i] == m.add(input[i]));
    }
}
