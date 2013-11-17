module stockd.ta.cci;

import std.math;
import std.stdio;
import stockd.defs.bar;

/**
 * Commodity Channel Index (CCI)
 * 
 * Ref: <a href="http://stockcharts.com/school/doku.php?st=cci&id=chart_school:technical_indicators:commodity_channel_in">stockcharts.com</a>
 * 
 * Introduction:
 * Developed by Donald Lambert and featured in Commodities magazine in 1980, the Commodity Channel Index (CCI) is a versatile indicator 
 * that can be used to identify a new trend or warn of extreme conditions. Lambert originally developed CCI to identify cyclical turns in 
 * commodities, but the indicator can successfully applied to indices, ETFs, stocks and other securities. 
 * In general, CCI measures the current price level relative to an average price level over a given period of time. 
 * CCI is relatively high when prices are far above their average. CCI is relatively low when prices are far below their average. 
 * In this manner, CCI can be used to identify overbought and oversold levels.
 * 
 * Calculation:
 * The example below is based on a 20-period Commodity Channel Index (CCI) calculation. The number of CCI periods is also used for the 
 * calculations of the simple moving average and Mean Deviation.
 * 
 * 
 * CCI = (Typical Price  -  20-period SMA of TP) / (.015 x Mean Deviation)
 * Typical Price (TP) = (High + Low + Close)/3
 * Constant = .015
 * 
 * There are four steps to calculating the Mean Deviation. First, subtract 
 * the most recent 20-period average of the typical price from each period's 
 * typical price. Second, take the absolute values of these numbers. Third, 
 * sum the absolute values. Fourth, divide by the total number of periods (20).
 */
class CCI
{
    private ushort period;
    private bool isFull;
    private double lastSum = 0;
    private ushort idx;
    private double[] buffer;

    this(ushort period = 14)
    {
        this.period = period;
        this.buffer = new double[period];
    }

    double add(Bar value)
    {
        double typical = (value.high + value.low + value.close)/3;
        double sma = 0;
        
        //get SMA
        if(!isFull)
        {
            buffer[idx++] = typical;
            lastSum += typical;
            
            if(idx == period)
            {
                idx = 0;
                isFull = true;
                sma = lastSum / period;
            }
            else sma = lastSum/(idx);
        }
        else
        {
            lastSum -= buffer[idx];
            buffer[idx++] = typical;
            lastSum += typical;
            if(idx == period) idx = 0;
            
            sma = lastSum / period;
        }
        
        double mean = 0;
        int len = isFull ? period : idx;
        for (int i = len - 1; i >= 0; i--) { mean += abs(buffer[i] - sma); }
        mean = mean / len;
        
        return (typical - sma) / (mean == 0 ? 1 : (0.015 * mean));
    }

    static void evaluate(const ref Bar[] input, ushort period, ref double[] output)
    {
        assert(input != null);
        assert(output != null);
        assert(input.length == output.length);
        assert(input.length > 0);

        double[] buffer = new double[period]; //to allow input and output arrays be the same
        ushort idx = 0;
        
        double typical = 0;
        double sma = 0;
        double sum = 0;
        double mean = 0;
        ulong i;
        
        for(i=0; i<period; i++)
        {
            typical = (input[i].high + input[i].low + input[i].close)/3;
            sum += (buffer[i] = typical);
            sma = sum/(i + 1);
            mean = 0;
            for (int j = cast(int)i; j >= 0; j--) { mean += abs(buffer[j] - sma); }
            mean = mean / (i + 1);
            output[i] = (typical - sma) / (mean == 0 ? 1 : (0.015 * mean));
        }
        
        for(i=period; i<input.length; i++)
        {
            typical = (input[i].high + input[i].low + input[i].close)/3;
            
            sum -= buffer[idx];
            sum += (buffer[idx] = typical);
            sma = sum / period;
            
            if(++idx == period) idx = 0;
            
            mean = 0;
            for (int j = period - 1; j >= 0; j--) { mean += abs(buffer[j] - sma); }
            mean = mean / period;
            output[i] = (typical - sma) / (mean == 0 ? 1 : 0.015 * mean);
        }
    }
}

unittest
{
    import std.csv;
    import std.stdio;
    import std.datetime;
    
    struct Layout {double open; double high; double low; double close;}
    
    auto strBars = r"23.94290;24.20130;23.85340;23.89320
23.85340;24.07210;23.72420;23.95280
23.94290;24.04230;23.64470;23.67450
23.73420;23.87330;23.36640;23.78390
23.59500;23.67450;23.45590;23.49560
23.45590;23.58510;23.17760;23.32170
23.52550;23.80370;23.39620;23.75400
23.73420;23.80360;23.56520;23.79380
24.09200;24.30070;24.05220;24.14170
23.95280;24.15160;23.77390;23.81370
23.92300;24.05220;23.59500;23.78390
24.04230;24.06220;23.84350;23.86340
23.83360;23.88330;23.64470;23.70440
24.05220;25.13560;23.94290;24.95670
24.88710;25.19520;24.73800;24.87710
24.94670;25.06600;24.76780;24.96160
24.90700;25.21510;24.89700;25.17530
25.24490;25.37410;24.92680;25.06600
25.12560;25.36420;24.95670;25.27470
25.26480;25.26480;24.92680;24.99640
24.73800;24.81750;24.21120;24.45970
24.36030;24.43980;24.21120;24.28080
24.48950;24.64850;24.42990;24.62370
24.69820;24.83740;24.43980;24.58150
24.64850;24.74790;24.20130;24.52680
24.47960;24.50940;24.25100;24.35040
24.45970;24.67840;24.21120;24.34040
24.61870;24.66840;24.15160;24.23110
23.81370;23.84350;23.63480;23.76400
23.91310;24.30070;23.76400;24.20130";

    auto records = csvReader!Layout(strBars,';');
    Bar[] bars;
    foreach(r; records)
    {
        bars ~= Bar(DateTime(2010, 1, 1, 1), r.open, r.high, r.low, r.close);
    }

    double[] expected = [0.00000, -66.66667, -100.00000, -101.00872, -115.38834, -126.05605, -20.49717, 7.39273, 148.20310, 52.05630, 14.03749, 55.03407, -17.10455, 259.92227, 243.90733, 182.08210, 166.50918, 142.16963, 131.64291, 102.31496, 30.73599, 6.55159, 33.29641, 34.95138, 13.84012, -10.74781, -11.58211, -29.34718, -129.35566, -73.06960];
    double[] eval = new double[expected.length];

    ushort period = 20;

    CCI.evaluate(bars, period, eval);
    assert(approxEqual(expected, eval));

    auto cci = new CCI(period);
    for(int i=0; i<bars.length; i++)
    {
        assert(approxEqual(expected[i], cci.add(bars[i])));
    }
}