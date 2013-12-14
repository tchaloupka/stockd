module stockd.defs.bar;

import std.datetime;
import stockd.defs.templates;

/**
 * Defines BAR structure
 */
struct Bar
{
    mixin property!(DateTime, "time");
    mixin property!(double, "open", 0);
    mixin property!(double, "high", 0);
    mixin property!(double, "low", 0);
    mixin property!(double, "close", 0);
    mixin property!(size_t, "volume");

    /**
     * Params:
     *  time  - date and time of bar in UTC
     *  open  - open price
     *  high  - highest bar price
     *  low   - lowest bar price
     *  close - closing price
     *  volume - traded stock volume
     */
    pure nothrow this(DateTime time, double open, double high, double low, double close, ulong volume = 0)
    {
        this._time = time;
        this._open = open;
        this._high = high;
        this._low = low;
        this._close = close;
        this._volume = volume;
    }

    /// Ensure BAR validity
    pure invariant()
    {
        import std.stdio;
        assert(_high >= _open && _high >= _low && _high >= _close);
        assert(_low <= _open && _low <= _close);
    }

    /// Returns just price values as OHLC array
    pure nothrow @property double[] ohlc() 
    {
        return [this.open, this.high, this.low, this.close];
    }
};