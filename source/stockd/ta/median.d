module stockd.ta.median;

import stockd.defs.bar;

/**
 * Evaluates median price for the specified period
 * 
 * median = (max + min)/2
 * 
 * Where max and min are evaluated from values within period
 */
class Median
{
    private ushort period;
    private ushort idx;
    private bool isBuffFull;
    private double max = int.min;
    private double min = int.max;
    private double[] hBuffer;
    private double[] lBuffer;

    this(ushort period = 14)
    {
        assert(period > 0);
        
        this.period = period;
        this.hBuffer = new double[period];
        this.lBuffer = new double[period];
    }

    pure nothrow double add(Bar value)
    {
        bool genMax = false;
        bool genMin = false;
        if (isBuffFull)
        {
            if (max == hBuffer[idx]) genMax = true;
            else if (value.high > max) { max = value.high; }
            if (min == lBuffer[idx]) genMin = true;
            else if (value.low < min) { min = value.low; }
        }
        else
        {
            if (value.high > max) { max = value.high; }
            if (value.low < min) { min = value.low; }
        }
        
        hBuffer[idx] = value.high;
        lBuffer[idx++] = value.low;
        if (idx == period)
        {
            isBuffFull = true;
            idx = 0;
        }
        
        if (genMax == true)
        {
            max = hBuffer[0];
            for (ushort i = 1; i < period; i++)
            {
                if (hBuffer[i] > max) max = hBuffer[i];
            }
        }

        if (genMin == true)
        {
            min = lBuffer[0];
            for (ushort i = 1; i < period; i++)
            {
                if (lBuffer[i] < min) min = lBuffer[i];
            }
        }

        return (max + min)/2;
    }

    static void evaluate(const ref Bar[] input, ushort period, ref double[] output)
    {
        assert(input != null);
        assert(output != null);
        assert(input.length == output.length);
        assert(input.length > 0);
        assert(period > 0);

        double min = int.max, max = int.min;
        ptrdiff_t trailingIdx = 0 - (period - 1);
        ptrdiff_t minIdx = -1, maxIdx = -1;
        size_t today, i;
        
        while (today < input.length)
        {
            if (minIdx < trailingIdx)
            {
                minIdx = trailingIdx;
                min = input[minIdx].low;
                i = minIdx;
                while (++i <= today)
                {
                    if (input[i].low <= min)
                    {
                        min = input[i].low;
                        minIdx = i;
                    }
                }
            }
            else if (input[today].low <= min)
            {
                min = input[today].low;
                minIdx = today;
            }

            if (maxIdx < trailingIdx)
            {
                maxIdx = trailingIdx;
                max = input[maxIdx].high;
                i = maxIdx;
                while (++i <= today)
                {
                    if (input[i].high >= max)
                    {
                        max = input[i].high;
                        maxIdx = i;
                    }
                }
            }
            else if (input[today].high >= max)
            {
                max = input[today].high;
                maxIdx = today;
            }
            
            output[today++] = (max + min)/2;
            trailingIdx++;
        }
    }
}

unittest
{
    import std.csv;
    import std.math;
    import std.stdio;
    import std.datetime;
    
    struct Layout {double high; double low;}
    
    auto strBars = r"127.009;125.3574
127.6159;126.1633
126.5911;124.9296
127.3472;126.0937
128.173;126.8199
128.4317;126.4817
127.3671;126.034
126.422;124.8301
126.8995;126.3921
126.8498;125.7156
125.646;124.5615
125.7156;124.5715
127.1582;125.0689
127.7154;126.8597
127.6855;126.6309
128.2228;126.8001
128.2725;126.7105
128.0934;126.8001
128.2725;126.1335
127.7353;125.9245
128.77;126.9891
129.2873;127.8148
130.0633;128.4715
129.1182;128.0641
129.2873;127.6059
128.4715;127.596
128.0934;126.999
128.6506;126.8995
129.1381;127.4865
128.6406;127.397
";
    
    auto records = csvReader!Layout(strBars,';');
    Bar[] bars;
    foreach(r; records)
    {
        bars ~= Bar(DateTime(2010, 1, 1, 1), r.high, r.high, r.low, r.low);
    }
    
    double[] expected = [126.1832,126.48665,126.27275,126.27275,126.5513,126.68065,126.68065,126.6309,126.6309,126.6309,126.4966,126.4966,125.9643,126.13845,126.13845,126.39215,126.417,126.422,126.6707,127.0985,127.34725,127.6059,127.9939,127.9939,127.9939,127.9939,128.5262,128.4814,128.4814,128.0934];
    double[] eval = new double[bars.length];

    ushort period = 7;

    Median.evaluate(bars, period, eval);
    assert(approxEqual(expected, eval));
    
    auto med = new Median(period);
    for(int i=0; i<bars.length; i++)
    {
        assert(approxEqual(expected[i], med.add(bars[i])));
    }
}

