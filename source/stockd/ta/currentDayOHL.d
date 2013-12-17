module stockd.ta.currentdayohl;

import std.datetime;
import stockd.defs.bar;
import stockd.defs.session;

/**
 * Indicates che current trading session day open, highest and lowest price to see the potencial price movement
 * 
 * Works only for a intraday data!!
 */
class CurrentDayOHL
{
    private TimeOfDay sessionStart;
    private DateTime lastTime = DateTime.min();
    private double curOpen;
    private double curHigh;
    private double curLow;

    /**
     * Params:
     *      sessionStart - time in UTC at whitch the trading session starts
     */
    this(TimeOfDay sessionStart)
    {
        this.sessionStart = sessionStart;
    }

    pure void add(Bar value, out double open, out double high, out double low)
    {
        if(isNextSession(lastTime, value.time, sessionStart))
        {
            curOpen = value.open;
            curHigh = value.high;
            curLow = value.low;
        }
        else
        {
            if(curHigh < value.high) curHigh = value.high;
            if(curLow > value.low) curLow = value.low;
        }
        
        open = curOpen;
        high = curHigh;
        low = curLow;
    }

    static void evaluate(const ref Bar[] input, TimeOfDay sessionStart, ref double[] open, ref double[] high, ref double[] low)
    {
        assert(input != null);
        assert(open != null);
        assert(high != null);
        assert(low != null);
        assert(input.length == open.length);
        assert(input.length == high.length);
        assert(input.length == low.length);
        assert(input.length > 0);

        double curOpen = input[0].open;
        double curHigh = input[0].high;
        double curLow = input[0].low;

        DateTime lastTime = DateTime.min;
        
        for(size_t i=0; i<input.length; i++)
        {
            if(isNextSession(lastTime, input[i].time, sessionStart))
            {
                curOpen = input[i].open;
                curHigh = input[i].high;
                curLow = input[i].low;
            }
            else
            {
                if(curHigh < input[i].high) curHigh = input[i].high;
                if(curLow > input[i].low) curLow = input[i].low;
            }
            
            open[i] = curOpen;
            high[i] = curHigh;
            low[i] = curLow;
        }
    }
}

unittest
{
    auto sessionStart = TimeOfDay(9, 0, 0);

    Bar[] bars = 
    [
        Bar(DateTime(2000, 1, 1, 8, 0, 0), 2, 3, 1, 2, 100),
        Bar(DateTime(2000, 1, 1, 8, 30, 0), 2.5, 5, 2, 3, 100),
        Bar(DateTime(2000, 1, 1, 9, 0, 0), 3, 3, 2, 2, 100),
        Bar(DateTime(2000, 1, 1, 9, 30, 0), 7, 9, 7, 8, 100),
        Bar(DateTime(2000, 1, 1, 10, 30, 0), 8, 12, 1, 11, 100)
    ];

    double[] expOpen = [2, 2, 3, 3, 3];
    double[] expHigh = [3, 5, 3, 9, 12];
    double[] expLow = [1, 1, 2, 2, 1];

    double[] evlOpen = new double[expOpen.length];
    double[] evlHigh = new double[expOpen.length];
    double[] evlLow = new double[expOpen.length];

    CurrentDayOHL.evaluate(bars, sessionStart, evlOpen, evlHigh, evlLow);
    assert(expOpen == evlOpen);
    assert(expHigh == evlHigh);
    assert(expLow == evlLow);

    auto cdOHL = new CurrentDayOHL(sessionStart);
    for(int i=0; i<bars.length; i++)
    {
        double o, h, l;
        cdOHL.add(bars[i], o, h, l);
        assert(expOpen[i] == o);
        assert(expHigh[i] == h);
        assert(expLow[i] == l);
    }
}