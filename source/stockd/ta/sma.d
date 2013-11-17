module stockd.ta.sma;

/** 
 * Simple moving average computed over a specified period of time
 */
class Sma
{
    private ushort period;
    private bool isFull;
    private double lastSum = 0;
    private ushort idx;
    private double[] buffer;
    
    /**
     * Params:
     *      period  = period SMA is calculated for
     */
    this(ushort period = 12)
    {
        assert(period > 0);
        
        this.period = period;
        this.buffer = new double[period];
    }
    
    /// Evaluate next value
    double add(double value)
    {
        if(!isFull)
        {
            buffer[idx++] = value;
            lastSum += value;
            
            if(idx == period)
            {
                idx = 0;
                isFull = true;
                return lastSum / period;
            }
            
            return lastSum / idx;
        }
        
        lastSum -= buffer[idx];
        buffer[idx++] = value;
        lastSum += value;
        if(idx == period) idx = 0;
        
        return lastSum / period;
    }
    
    /// Evaluate SMA for the whole input array
    static void evaluate(const ref double[] input, ushort period, ref double[] output)
    {
        assert(input != null);
        assert(output != null);
        assert(input.length == output.length);
        assert(input.length > 0);
        assert(period > 0);
        
        double sum = 0;
        double[] buffer = new double[period]; //to allow input and output arrays be the same
        ushort idx = 0;
        ulong i = 0;
        
        for(; i<period; i++)
        {
            sum += (buffer[i] = input[i]);
            output[i] = sum / (i + 1);
        }
        
        for(; i<input.length; i++)
        {
            sum -= buffer[idx];
            sum += (buffer[idx] = input[i]);
            
            if(++idx == period) idx = 0;
            
            output[i] = sum / period;
        }
    }
}

unittest
{
    import std.math;
    import std.stdio;
    
    ushort period = 10;
    double[] input    = [22.27340, 22.19400, 22.08470, 22.17410, 22.18400, 22.13440, 22.23370, 22.43230, 22.24360, 22.29330, 22.15420, 22.39260, 22.38160, 22.61090, 23.35580, 24.05190, 23.75300, 23.83240, 23.95160, 23.63380, 23.82250, 23.87220, 23.65370, 23.18700, 23.09760, 23.32600, 22.68050, 23.09760, 22.40250, 22.17250];
    double[] expected = [22.27340, 22.23370, 22.18403, 22.18155, 22.18204, 22.17410, 22.18261, 22.21383, 22.21713, 22.22475, 22.21283, 22.23269, 22.26238, 22.30606, 22.42324, 22.61499, 22.76692, 22.90693, 23.07773, 23.21178, 23.37861, 23.52657, 23.65378, 23.71139, 23.68557, 23.61298, 23.50573, 23.43225, 23.27734, 23.13121];
    double[] evaluated = new double[input.length];
    
    Sma.evaluate(input, period, evaluated);
    assert(approxEqual(expected, evaluated));
    
    auto sma = new Sma(period);
    for(int i=0; i<input.length; i++)
    {
        assert(approxEqual(expected[i], sma.add(input[i])));
    }
}

