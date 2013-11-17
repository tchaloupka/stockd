module stockd.ta.bollinger;

import std.math;
import std.stdio;

/**
 * Bollinger Bands
 * 
 * Ref: <a href="http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:bollinger_bands">stockcharts.com</a>
 * 
 * Introduction:
 * 
 * Developed by John Bollinger, Bollinger Bands® are volatility bands placed above and below a moving average. 
 * Volatility is based on the standard deviation, which changes as volatility increases and decreases. The bands automatically widen when 
 * volatility increases and narrow when volatility decreases. This dynamic nature of Bollinger Bands also means they can be used on 
 * different securities with the standard settings. For signals, Bollinger Bands can be used to identify M-Tops and W-Bottoms or to determine 
 * the strength of the trend.
 * 
 * Note: Bollinger Bands® is a registered trademark of John Bollinger.
 * 
 * Calculation:
 *      Middle Band = 20-day simple moving average (SMA)
 *      Upper Band = 20-day SMA + (20-day standard deviation of price x 2) 
 *      Lower Band = 20-day SMA - (20-day standard deviation of price x 2)
 */
class Bollinger
{
    private ushort period;
    private double stdDevNum;

    private bool isFull;
    private double lastSum = 0;
    private ushort idx;
    private double[] buffer;

    this(ushort period = 14, double stdDevNum = 2)
    {
        assert(period > 0);

        this.period = period;
        this.stdDevNum = stdDevNum;
        this.buffer = new double[period];
    }

    void add(double value, out double middle, out double upper, out double lower)
    {
        //get Average
        if(!isFull)
        {
            buffer[idx++] = value;
            lastSum += value;
            
            if(idx == 1)
            {
                if(idx == period)
                {
                    idx = 0;
                    isFull = true;
                }
                middle = value;
                upper = value;
                lower = value;
                return;
            }
            if(idx == period)
            {
                idx = 0;
                isFull = true;
                middle = lastSum / period;
            }
            else middle = lastSum / idx;
        }
        else
        {
            lastSum -= buffer[idx];
            buffer[idx++] = value;
            lastSum += value;
            if(idx == period) idx = 0;
            middle = lastSum / period;
        }
        
        //count stddev
        double sum = 0;
        for(ushort i = 0; i < (isFull ? period: idx); i++)
        {
            sum += (buffer[i] - middle)*(buffer[i] - middle);
        }
        
        sum = sqrt(sum / (isFull ? period : idx));
        upper = middle + sum * stdDevNum;
        lower = middle - sum * stdDevNum;
    }

    static void evaluate(const ref double[] input, ushort period, double stdDevNum, ref double[] middle, ref double[] upper, ref double[] lower)
    {
        assert(input != null);
        assert(middle != null);
        assert(upper != null);
        assert(lower != null);
        assert(input.length == middle.length);
        assert(input.length == upper.length);
        assert(input.length == lower.length);
        assert(input.length > 0);
        assert(period > 0);
        
        double sum = 0;
        double[] buffer = new double[period]; //to allow input and output arrays be the same
        ushort idx = 0;
        ulong i = 1;
        
        sum += (buffer[0] = input[0]);
        middle[0] = input[0];
        upper[0] = input[0];
        lower[0] = input[0];
        
        for(; i<period; i++)
        {
            sum += (buffer[i] = input[i]);
            middle[i] = sum / (i + 1);
            double tmp = 0;
            for(ushort j = 0; j <= i; j++)
            {
                tmp += (buffer[j] - middle[i])*(buffer[j] - middle[i]);
            }
            tmp = sqrt(tmp / (i + 1));
            upper[i] = middle[i] + stdDevNum * tmp;
            lower[i] = middle[i] - stdDevNum * tmp;
        }
        
        for(; i<input.length; i++)
        {
            sum -= buffer[idx];
            sum += (buffer[idx] = input[i]);
            
            if(++idx == period) idx = 0;
            middle[i] = sum / period;
            double tmp = 0;
            for(ushort j = 0; j < period; j++)
            {
                tmp += (buffer[j] - middle[i])*(buffer[j] - middle[i]);
            }
            tmp = sqrt(tmp / period);
            upper[i] = middle[i] + stdDevNum * tmp;
            lower[i] = middle[i] - stdDevNum * tmp;
        }
    }
}

unittest
{
    import std.stdio;
    
    ushort period = 20;
    double[] input    = [86.15570,89.08670,88.78290,90.32280,89.06710,91.14530,89.43970,89.17500,86.93020,87.67520,86.95960,89.42990,89.32210,88.72410,87.44970,87.26340,89.49850,87.90060,89.12600,90.70430,92.90010,92.97840,91.80210,92.66470,92.68430,92.30210,92.77250,92.53730,92.94900,93.20390,91.06690,89.83180,89.74350,90.39940,90.73870,88.01770,88.08670,88.84390,90.77810,90.54160,91.38940,90.65000];
    double[] expMid = [86.15570,87.62120,88.00843,88.58703,88.68304,89.09342,89.14289,89.14690,88.90060,88.77806,88.61275,88.68084,88.73017,88.72974,88.64440,88.55809,88.61341,88.57381,88.60287,88.70794,89.04516,89.23975,89.39071,89.50780,89.68866,89.74650,89.91314,90.08126,90.38220,90.65863,90.86400,90.88409,90.90516,90.98893,91.15338,91.19109,91.12050,91.16767,91.25027,91.24214,91.16660,91.05018];
    double[] expUpper = [86.15570,90.55220,90.64031,91.62220,91.42482,92.19706,92.02651,91.84436,91.80044,91.62565,91.52217,91.50279,91.46286,91.36303,91.26733,91.18425,91.19931,91.10798,91.08175,91.29186,91.94927,92.61260,92.93420,93.31195,93.72845,93.89959,94.26625,94.56510,94.78691,95.04300,94.90761,94.90291,94.89532,94.86101,94.67363,94.55659,94.67875,94.57579,94.53427,94.53231,94.36925,94.14850];
    double[] expLower = [86.15570,84.69020,85.37656,85.55185,85.94126,85.98977,86.25926,86.44944,86.00076,85.93047,85.70332,85.85890,85.99748,86.09645,86.02147,85.93192,86.02750,86.03963,86.12399,86.12402,86.14105,85.86689,85.84721,85.70365,85.64887,85.59341,85.56003,85.59741,85.97748,86.27426,86.82038,86.86527,86.91500,87.11684,87.63312,87.82559,87.56225,87.75954,87.96627,87.95196,87.96395,87.95186];
    double[] evalMid = new double[input.length];
    double[] evalUpper = new double[input.length];
    double[] evalLower = new double[input.length];
    
    Bollinger.evaluate(input, period, 2.0, evalMid, evalUpper, evalLower);
    assert(approxEqual(expMid, evalMid));
    assert(approxEqual(expUpper, evalUpper));
    assert(approxEqual(expLower, evalLower));
    
    auto bol = new Bollinger(period);
    for(int i=0; i<input.length; i++)
    {
        double m, u, l;
        bol.add(input[i], m, u, l);
        assert(approxEqual(expMid[i], m));
        assert(approxEqual(expUpper[i], u));
        assert(approxEqual(expLower[i], l));
    }
}