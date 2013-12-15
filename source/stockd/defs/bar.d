module stockd.defs.bar;

import std.array;
import std.stdio;
import std.csv;
import std.datetime;
import stockd.defs.templates;
import std.string : format;
import std.typecons : Nullable;

enum FileFormat {NinjaTrader, TradeStation}

/**
 * Defines BAR structure
 */
struct Bar
{
    struct NTLayout {string date; double open; double high; double low; double close;size_t volume;}
    struct TSLayoutLong {string date; string time; double open; double high; double low; double close;size_t volume;}
    alias NTLayout TSLayoutShort;

    private bool hasTOD;
    private DateTime _time;
    @property pure nothrow public DateTime time() const { return _time; }
    @property pure nothrow public void time(DateTime value) { _time = value; hasTOD = true; }
    @property pure nothrow public void time(Date value) { _time = DateTime(value); hasTOD = false; }

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
        this.hasTOD = true;
    }

    /**
     * Params:
     *  date  - date of bar in UTC
     *  open  - open price
     *  high  - highest bar price
     *  low   - lowest bar price
     *  close - closing price
     *  volume - traded stock volume
     */
    pure nothrow this(Date date, double open, double high, double low, double close, ulong volume = 0)
    {
        this._time = DateTime(date);
        this._open = open;
        this._high = high;
        this._low = low;
        this._close = close;
        this._volume = volume;
        this.hasTOD = false;
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

    /**
     * Gets CSV format string of the BAR
     * 
     * NT format is:
     * yyyyMMdd HHmmss;open price;high price;low price;close price;volume
     * or
     * yyyyMMdd;open price;high price;low price;close price;volume
     * 
     * TS format is:
     * MM/dd/yyyy,HHMM,open price, high price, low price, volume
     * or
     * MM/dd/yyyy,open price, high price, low price, volume
     */
    string toString(FileFormat ff = FileFormat.NinjaTrader) const
    {
        final switch(ff)
        {
            case FileFormat.NinjaTrader:
                if(hasTOD)
                {
                    return format("%d%02d%02d %02d%02d%02d;%.5f;%.5f;%.5f;%.5f;%d", 
                          time.year, time.month, time.day, time.hour, time.minute, time.second,
                          _open, _high, _low, _close, _volume);
                }
                return format("%d%02d%02d;%.5f;%.5f;%.5f;%.5f;%d", 
                      time.year, time.month, time.day,
                      _open, _high, _low, _close, _volume);
            case FileFormat.TradeStation:
                if(hasTOD)
                {
                    return format("%02d/%02d/%d,%02d%02d,%.5f,%.5f,%.5f,%.5f,%d", 
                                  time.month, time.day, time.year, time.hour, time.minute,
                                  _open, _high, _low, _close, _volume);
                }
                return format("%02d/%02d/%d,%.5f,%.5f,%.5f,%.5f,%d", 
                              time.month, time.day, time.year,
                              _open, _high, _low, _close, _volume);
        }
    }

    /**
     * Tries to guess fileformat for BAR from the input string
     * Returns null if undeterminable
     */
    static Nullable!FileFormat guessFileFormat(in string data)
    {
        try
        {
            auto fields = data.split(";");
            if(fields.length == 6)
            {
                //probably NT
                auto records = csvReader!NTLayout(data,';');
                auto rec = records.front;

                return Nullable!FileFormat(FileFormat.NinjaTrader);
            }

            fields = data.split(",");
            if(fields.length == 7)
            {
                //probably TS
                auto records = csvReader!TSLayoutLong(data,';');
                auto rec = records.front;
                
                return Nullable!FileFormat(FileFormat.TradeStation);
            }
            if(fields.length == 6)
            {
                //probably TS
                auto records = csvReader!TSLayoutShort(data,';');
                auto rec = records.front;
                
                return Nullable!FileFormat(FileFormat.TradeStation);
            }
        }
        catch(CSVException e)
        {
            writeln("Error guessing fileformat: ", e);
        }

        return Nullable!FileFormat();
    }
}

unittest
{
    import std.stdio;
    import std.conv;

    //Test NT format output
    Bar b = Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 100);
    assert(b.toString(FileFormat.NinjaTrader) == "20100302 050607;58.67865;58.82547;57.03316;57.73132;100");
    assert(to!string(b) == "20100302 050607;58.67865;58.82547;57.03316;57.73132;100");

    b = Bar(Date(2010, 3, 12), 58.678654, 58.825467, 57.033158, 57.7313214, 100);
    assert(b.toString(FileFormat.NinjaTrader) == "20100312;58.67865;58.82547;57.03316;57.73132;100");

    //Test TS format output
    b = Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 100);
    assert(b.toString(FileFormat.TradeStation) == "03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100");

    b = Bar(Date(2010, 3, 2), 58.678654, 58.825467, 57.033158, 57.7313214, 100);
    assert(b.toString(FileFormat.TradeStation) == "03/02/2010,58.67865,58.82547,57.03316,57.73132,100");

    //Test guessing FileFormat
    assert(Bar.guessFileFormat("20100302 050607;58.67865;58.82547;57.03316;57.73132;100") == FileFormat.NinjaTrader);
    assert(Bar.guessFileFormat("20100302;58.67865;58.82547;57.03316;57.73132;100") == FileFormat.NinjaTrader);
    assert(Bar.guessFileFormat("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100") == FileFormat.TradeStation);
    assert(Bar.guessFileFormat("03/02/2010,58.67865,58.82547,57.03316,57.73132,100") == FileFormat.TradeStation);
    assert(Bar.guessFileFormat("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100,500").isNull);
    assert(Bar.guessFileFormat("20100302;58.67865;58.82547;57.03316;57.73132").isNull);
    assert(Bar.guessFileFormat("a;b;c;d;e;f").isNull);
    assert(Bar.guessFileFormat("a;b;c,d;e;f").isNull);
    assert(Bar.guessFileFormat("blablabla").isNull);
}