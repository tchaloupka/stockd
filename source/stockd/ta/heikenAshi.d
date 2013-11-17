module stockd.ta.heikenAshi;

import std.algorithm;
import std.stdio;
import stockd.defs.bar;

/**
 * Heikin-Ashi Price Bars
 * 
 * Ref: <a href="http://stockcharts.com/school/doku.php?st=heiken+ashi&id=chart_school:chart_analysis:heikin_ashi">stockcharts.com</a>
 * 
 * Heikin-Ashi Candlesticks are an offshoot from Japanese candlesticks. Heikin-Ashi Candlesticks use the open-close data from the prior period 
 * and the open-high-low-close data from the current period to create a combo candlestick. The resulting candlestick filters out some noise in 
 * an effort to better capture the trend. In Japanese, Heikin means "average" and "ashi" means "pace" (EUDict.com). Taken together, 
 * Heikin-Ashi represents the average-pace of prices. Heikin-Ashi Candlesticks are not used like normal candlesticks. Dozens of bullish or bearish 
 * reversal patterns consisting of 1-3 candlesticks are not to be found. Instead, these candlesticks can be used to identify trending periods, 
 * potential reversal points and classic technical analysis patterns.
 * 
 * HaClose = (Open+High+Low+Close)/4
 *      = the average price of the current bar
 * HaOpen = [HaOpen(previous bar) + Close(previous bar)]/2
 *      = the midpoint of the previous bar
 * HaHigh = Max(High, HaOpen, HaClose)
 *      = the highest value in the range
 * HaLow = Min(Low, HaOpen, HaClose)
 *      = the lowest value in the range 
 */
class HeikenAshi
{
    private Bar prevBar = Bar();
    private bool first = true;

    this()
    {
        // Constructor code
    }

    Bar Add(Bar value)
    {
        if(first)
        {
            //return input bar
            prevBar.time = value.time;
            prevBar.open = (value.open + value.close) * 0.5; // Calculate the close
            prevBar.high = value.high;
            prevBar.low = value.low;
            prevBar.close = (value.open + value.high + value.low + value.close) * 0.25; // Calculate the close
            prevBar.volume = value.volume;
            first = false;
        }
        else
        {
            prevBar.time = value.time;
            prevBar.open = (prevBar.open + prevBar.close) * 0.5; // Calculate the open
            prevBar.close = (value.open + value.high + value.low + value.close) * 0.25; // Calculate the close
            prevBar.high = max(value.high, prevBar.open, prevBar.close); // Calculate the high
            prevBar.low = min(value.low, prevBar.open, prevBar.close); // Calculate the low
            prevBar.volume = value.volume;
        }

        return prevBar;
    }

    static void evaluate(const ref Bar[] input, ref Bar[] output)
    {
        assert(input != null);
        assert(output != null);
        assert(input.length == output.length);
        assert(input.length > 0);

        //return input bar
        output[0].time = input[0].time;
        output[0].open = (input[0].open + input[0].close) * 0.5; // Calculate the close
        output[0].high = input[0].high;
        output[0].low = input[0].low;
        output[0].close = (input[0].open + input[0].high + input[0].low + input[0].close) * 0.25; // Calculate the close
        output[0].volume = input[0].volume;

        for(ulong i=1; i<input.length; i++)
        {
            output[i].time = input[i].time;
            output[i].open = (output[i-1].open + output[i-1].close) * 0.5; // Calculate the open
            output[i].close = (input[i].open + input[i].high + input[i].low + input[i].close) * 0.25; // Calculate the close
            output[i].high = max(input[i].high, output[i].open, output[i].close); // Calculate the high
            output[i].low = min(input[i].low, output[i].open, output[i].close); // Calculate the low
            output[i].volume = input[i].volume;
        }
    }
}

unittest
{
    import std.datetime;
    import std.math;

    Bar[] bars = 
    [
        Bar(DateTime(2000, 1, 1), 58.67, 58.82, 57.03, 57.73, 100),
        Bar(DateTime(2000, 1, 1), 57.46, 57.72, 56.21, 56.27, 100),
        Bar(DateTime(2000, 1, 1), 56.37, 56.88, 55.35, 56.81, 100)
    ];

    Bar[] expected = 
    [
        Bar(DateTime(2000, 1, 1), 58.2, 58.82, 57.03, 58.0625, 100),
        Bar(DateTime(2000, 1, 1), 58.13125, 58.13125, 56.21, 56.915, 100),
        Bar(DateTime(2000, 1, 1), 57.523125, 57.523125, 55.35, 56.3525, 100)
    ];
    auto eval = new Bar[bars.length];

    HeikenAshi.evaluate(bars, eval);

    auto ha = new HeikenAshi();
    for(int i=0; i<bars.length; i++)
    {
        assert(expected[i].time == eval[i].time);
        assert(expected[i].volume == eval[i].volume);
        assert(approxEqual(expected[i].ohlc(), eval[i].ohlc()));

        auto hab = ha.Add(bars[i]);
        assert(expected[i].time == hab.time);
        assert(expected[i].volume == hab.volume);
        assert(approxEqual(expected[i].ohlc(), hab.ohlc()));
    }
}