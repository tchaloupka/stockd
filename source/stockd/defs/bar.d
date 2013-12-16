module stockd.defs.bar;

import std.algorithm;
import std.array;
import std.datetime;
import std.conv;
import std.csv;
import std.stdio;
import std.string;
import std.typecons;

import stockd.defs.templates;

enum FileFormat {NinjaTrader, TradeStation} //TODO: guess and make it a default in methods

/**
 * Template whitch helps create Bar from Bar array
 */
template createBar(T) 
    if(is(T==DateTime) || is(T == Date))
{
    Bar createBar(T)(in Bar[] bars, T time)
    {
        assert(bars.length > 0);
        
        auto r = reduce!(
            (a,b) => a > b.low ? b.low : a, // get min low
            (a,b) => a < b.high ? b.high : a, // get max high
            (a,b) => a + b.volume)  // sum volume
            (tuple(cast(double)int.max, 0.0, cast(size_t)0), bars);
        
        return Bar(time, bars[0].open, r[1], r[0], bars[$-1].close, r[2]);
    }
}

/// Template which reads Bars from multiline string
/// 
/// Returns:
/// input range of Bars
template readBars()
{
    auto readBars(string data, FileFormat ff = FileFormat.NinjaTrader)
    {
        return data.splitter('\n').map!(b => Bar.fromString(b, ff));
    }
}

/**
 * Defines BAR structure
 */
struct Bar
{
    struct NTLayout {string date; double open; double high; double low; double close;size_t volume;}
    struct TSLayoutLong {string date; string time; double open; double high; double low; double close;size_t volume;}
    alias NTLayout TSLayoutShort;

//    yyyyMMdd HHmmss;open price;high price;low price;close price;volume
//        * or
//            * yyyyMMdd;open price;high price;low price;close price;volume
//        * 
//            * TS format is:
//            * MM/dd/yyyy,HHMM

//    mixin template read

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
        return [this._open, this._high, this._low, this._close];
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
    	//TODO: add posibility to chose target TimeZone
        final switch(ff)
        {
            case FileFormat.NinjaTrader:
                if(hasTOD)
                {
                    return format("%s %s;%.5f;%.5f;%.5f;%.5f;%d", 
                          time.date.toISOString, time.timeOfDay.toISOString,
                          _open, _high, _low, _close, _volume);
                }
                return format("%s;%.5f;%.5f;%.5f;%.5f;%d", 
                      time.date.toISOString,
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
    static Nullable!FileFormat guessFileFormat(in string data)
    {
    	//TODO: use regex
	    //TODO" add variant from http://www.intradaystockdata.com/sample_files.html
	    //TODO" add variants from http://www.histdata.com/f-a-q/data-files-detailed-specification/

        try
        {
            auto fields = data.split(";");
            if(fields.length == 5 || fields.length == 6)
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
                auto records = csvReader!TSLayoutLong(data);
                auto rec = records.front;
                
                return Nullable!FileFormat(FileFormat.TradeStation);
            }
            if(fields.length == 6)
            {
                //probably TS
                auto records = csvReader!TSLayoutShort(data);
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

    /**
     * Parse BAR from input string
     * 
     * NT format is:
     * yyyyMMdd HHmmss;open price;high price;low price;close price;volume
     * or
     * yyyyMMdd;open price;high price;low price;close price;volume
     * 
     * TS format is:
     * MM/dd/yyyy,HHmm,open price, high price, low price, volume
     * or
     * MM/dd/yyyy,open price, high price, low price, volume
     * 
     * Throws:
     * CSVException if provided string does not conform to the specified FileFormat
     * DateTimeException if the given string is not in the ISO format or
     */
    static Bar fromString(const string data, FileFormat ff = FileFormat.NinjaTrader)
    {
    	//TODO: add possibility to specify source TimeZone
        string stripped = data.strip;
        final switch(ff)
        {
            case(FileFormat.NinjaTrader):
                auto fields = stripped.split(";");
                if(fields.length != 5 && fields.length != 6) throw new Exception(stripped ~ " is not a valid NT format");

                auto records = csvReader!NTLayout(stripped,';');
                auto rec = records.front;
                if(rec.date.length == 15)
                    return Bar(
                        DateTime(Date.fromISOString(rec.date[0..8]), TimeOfDay.fromISOString(rec.date[8..$])), 
                        rec.open, rec.high, rec.low, rec.close, rec.volume);
                return Bar(Date.fromISOString(rec.date), rec.open, rec.high, rec.low, rec.close, rec.volume);
            case(FileFormat.TradeStation):
                auto fields = stripped.split(",");
                if(fields.length != 7 && fields.length != 6) throw new Exception(stripped ~ " is not a valid TS format");
                if(fields.length == 6) //short
                {
                    auto records = csvReader!TSLayoutShort(stripped);
                    auto rec = records.front;
                    return Bar(
                        Date(to!int(rec.date[6..$]), to!int(rec.date[0..2]), to!int(rec.date[3..5])), // MM/dd/yyyy
                        rec.open, rec.high, rec.low, rec.close, rec.volume);
                }
                else //long
                {
                    auto records = csvReader!TSLayoutLong(stripped);
                    auto rec = records.front;
                    return Bar(
                        DateTime(
                            Date(to!int(rec.date[6..$]), to!int(rec.date[0..2]), to!int(rec.date[3..5])), // MM/dd/yyyy
                            TimeOfDay(to!int(rec.time[0..2]), to!int(rec.time[2..$])) // HHmm
                        ), rec.open, rec.high, rec.low, rec.close, rec.volume);
                }
        }
    }
}

unittest
{
    import std.exception;

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
    assert(Bar.guessFileFormat("20100302;58.67865;58.82547;57.03316;57.73132") == FileFormat.NinjaTrader);
    assert(Bar.guessFileFormat("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100") == FileFormat.TradeStation);
    assert(Bar.guessFileFormat("03/02/2010,58.67865,58.82547,57.03316,57.73132,100") == FileFormat.TradeStation);
    assert(Bar.guessFileFormat("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100,500").isNull);
    assert(Bar.guessFileFormat("a;b;c;d;e;f").isNull);
    assert(Bar.guessFileFormat("a,b,c,d,e,f").isNull);
    assert(Bar.guessFileFormat("blablabla").isNull);

    //Test Bar.fromString
    b = Bar.fromString("20100302 050607;58.678654;58.825467;57.033158;57.7313214;100");
    assert(b == Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 100));
    assert(b.hasTOD);
    b = Bar.fromString("20100302 050607;58.678654;58.825467;57.033158;57.7313214");
    assert(b == Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 0));
    b = Bar.fromString("20100312;58.678654;58.825467;57.033158;57.7313214;100");
    assert(b == Bar(Date(2010, 3, 12), 58.678654, 58.825467, 57.033158, 57.7313214, 100));
    assert(!b.hasTOD);

    b = Bar.fromString("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100", FileFormat.TradeStation);
    assert(b == Bar(DateTime(2010, 3, 2, 5, 6, 0), 58.67865, 58.82547, 57.03316, 57.73132, 100));
    assert(b.hasTOD);
    b = Bar.fromString("03/02/2010,58.67865,58.82547,57.03316,57.73132,100", FileFormat.TradeStation);
    assert(b == Bar(Date(2010, 3, 2), 58.67865, 58.82547, 57.03316, 57.73132, 100));
    assert(!b.hasTOD);

    assertThrown(Bar.fromString("a;b;c;d;e;f"));
    assertThrown(Bar.fromString("a,b,c,d,e,f"));
    assertThrown(Bar.fromString("blablabla"));

    assertThrown(Bar.fromString("a;b;c;d;e;f", FileFormat.TradeStation));
    assertThrown(Bar.fromString("a,b,c,d,e,f", FileFormat.TradeStation));
    assertThrown(Bar.fromString("blablabla", FileFormat.TradeStation));
}
