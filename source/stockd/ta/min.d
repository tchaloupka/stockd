module stockd.ta.min;

import std.stdio;

/// Minimal value for the specified time period
class Min
{
    private ushort period;
    private ushort idx;
    private bool isBuffFull;
    private double min = int.max;
    private double[] buffer;

    this(ushort period = 14)
    {
        assert(period > 0); 

        this.period = period;
        this.buffer = new double[period];
    }

    /// Add next value, returns current min for the period
    double add(double value)
    {
        bool genMin = false;
        if (isBuffFull)
        {
            if (min == buffer[idx]) genMin = true;
            else if (value < min) min = value;
        }
        else
        {
            if (value < min) min = value;
        }
        
        buffer[idx++] = value;
        if (idx == period)
        {
            isBuffFull = true;
            idx = 0;
        }
        
        if (genMin == true)
        {
            min = buffer[0];
            for (ushort i = 1; i < period; i++)
            {
                if (buffer[i] < min) min = buffer[i];
            }
        }
        
        return min;
    }

    /// Evaluates min value for the whole input array
    static void evaluate(const ref double[] input, ushort period, ref double[] output)
    {
    	assert(input != null);
    	assert(output != null);
    	assert(input.length == output.length);
        assert(input.length > 0);
    	assert(period > 0);
        
        double min = int.max, tmp;
        long trailingIdx = 0 - (period - 1);
        long today = 0;
        long minIdx = -1;
        long i;
        long length = input.length;
        
        while (today < length)
        {
            tmp = input[today];
            
            if (minIdx < trailingIdx)
            {
                minIdx = trailingIdx;
                min = input[minIdx];
                i = minIdx;
                while (++i <= today)
                {
                    tmp = input[i];
                    if (tmp <= min)
                    {
                        min = tmp;
                        minIdx = i;
                    }
                }
            }
            else if (tmp <= min)
            {
                min = tmp;
                minIdx = today;
            }
            
            output[today++] = min;
            trailingIdx++;
        }
    }
}

unittest
{
    ushort period = 4;
    double[] input    = [1,2,3,4,5,2,3,4,5,3,4,5,6];
    double[] expected = [1,1,1,1,2,2,2,2,2,3,3,3,3];
    double[] evaluated = new double[input.length];
    
    Min.evaluate(input, period, evaluated);
    assert(evaluated == expected);
    
    auto m = new Min(period);
    for(int i=0; i<input.length; i++)
    {
        assert(expected[i] == m.add(input[i]));
    }
}
