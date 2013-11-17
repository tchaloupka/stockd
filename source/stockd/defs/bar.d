module stockd.defs.bar;

import std.datetime;

/**
 * Defines BAR structure
 */
struct Bar
{
    /// Time of BAR
    DateTime time;
    /// Open price
    double open;
    /// Highest bar price
    double high;
    /// Lowest bar price
    double low;
    /// Close price
    double close;
    /// Volume traded
    ulong volume;

    /**
     * Params:
     *  time  - date and time of bar
     *  open  - open price
     *  high  - highest bar price
     *  low   - lowest bar price
     *  close - closing price
     *  volume - traded stock volume
     */
    this(DateTime time, double open, double high, double low, double close, ulong volume = 0)
    {
        assert(high >= open && high >= low && high >= close);
        assert(low <= open && low <= close);

        this.time = time;
        this.open = open;
        this.high = high;
        this.low = low;
        this.close = close;
        this.volume = volume;
    }

    /// Returns just price values as OHLC array
    double[] ohlc() { return [this.open, this.high, this.low, this.close]; }
};