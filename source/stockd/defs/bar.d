module stockd.defs.bar;

import stockd.defs.templates;
import std.datetime;

enum FileFormat {ninjaTrader, tradeStation, guess}

/**
 * Defines BAR structure
 */
struct Bar
{
    import std.datetime;
    import std.typecons;
    import std.range;

    struct NTLayout {string date; double open; double high; double low; double close;size_t volume;}
    struct TSLayoutLong {string date; string time; double open; double high; double low; double close;size_t volume;}
    alias NTLayout TSLayoutShort;

//    yyyyMMdd HHmmss;open price;high price;low price;close price;volume
//        * or
//            * yyyyMMdd;open price;high price;low price;close price;volume
//        * 
//            * TS format is:
//            * MM/dd/yyyy,HHMM

    private bool hasTOD;
    private DateTime _time;
    @property @safe @nogc pure nothrow public DateTime time() const { return _time; }
    @property @safe @nogc pure nothrow public void time(DateTime value) { _time = value; hasTOD = true; }
    @property @safe pure nothrow public void time(Date value) { _time = DateTime(value); hasTOD = false; }

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
     * 
     * Note:
     * if guess file format is specified, it should be noted that than guesFileFormat is called and if many bars are created this way, every
     * bar is created this guessing way so it is unnecessary slower -> so for bigger data use guessFileFormat before and call this with its output
     */
    this(in string data, FileFormat ff = FileFormat.guess)
    {
        enum setOHLC = "this._open = rec.open; this._high = rec.high; this._low = rec.low; this._close = rec.close; this._volume = rec.volume;";

        import std.string : strip;
        import std.array;
        import std.conv;
        import std.csv;
        
        //TODO: add possibility to specify source TimeZone so we can convert input datetime to internal UTC
        string stripped = data.strip;

        auto fileFormat = Bar.guessFileFormat(stripped);
        if(fileFormat.isNull) throw new Exception("Unknown input data: " ~ data);
        ff = fileFormat;

        final switch(ff)
        {
            case(FileFormat.ninjaTrader):
                auto fields = stripped.split(";");
                if(fields.length != 5 && fields.length != 6) throw new Exception(stripped ~ " is not a valid NT format");
                
                auto records = csvReader!NTLayout(stripped,';');
                auto rec = records.front;
                if(rec.date.length == 15)
                {
                    this.time = DateTime(Date.fromISOString(rec.date[0..8]), TimeOfDay.fromISOString(rec.date[8..$]));
                }
                else
                {
                    this.time = Date.fromISOString(rec.date);
                }
                mixin(setOHLC);
                break;
            case(FileFormat.tradeStation):
                auto fields = stripped.split(",");
                if(fields.length != 7 && fields.length != 6) throw new Exception(stripped ~ " is not a valid TS format");
                if(fields.length == 6) //short
                {
                    auto records = csvReader!TSLayoutShort(stripped);
                    auto rec = records.front;
                    this.time = Date(to!int(rec.date[6..$]), to!int(rec.date[0..2]), to!int(rec.date[3..5])); // MM/dd/yyyy
                    mixin(setOHLC);
                }
                else //long
                {
                    auto records = csvReader!TSLayoutLong(stripped);
                    auto rec = records.front;
                    this.time = DateTime(
                        Date(to!int(rec.date[6..$]), to!int(rec.date[0..2]), to!int(rec.date[3..5])), // MM/dd/yyyy
                        TimeOfDay(to!int(rec.time[0..2]), to!int(rec.time[2..$]))); // HHmm
                    mixin(setOHLC);
                }
                break;
            case(FileFormat.guess):
                assert(0, "Invalid operation");
        }
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
    string toString(FileFormat ff = FileFormat.ninjaTrader) const
    {
        import std.string : format;

    	//TODO: add posibility to chose target TimeZone
        final switch(ff)
        {
            case FileFormat.guess:
                //fall back to the default FileFormat
            case FileFormat.ninjaTrader:
                if(hasTOD)
                {
                    return format("%s %s;%.5f;%.5f;%.5f;%.5f;%d", 
                          time.date.toISOString, time.timeOfDay.toISOString,
                          _open, _high, _low, _close, _volume);
                }
                return format("%s;%.5f;%.5f;%.5f;%.5f;%d", 
                      time.date.toISOString,
                      _open, _high, _low, _close, _volume);
            case FileFormat.tradeStation:
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
    static Nullable!FileFormat guessFileFormat(in char[] data)
    {
        import std.csv;
        import std.array;

    	//TODO: use regex - faster?
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

                return Nullable!FileFormat(FileFormat.ninjaTrader);
            }

            fields = data.split(",");
            if(fields.length == 7)
            {
                //probably TS
                auto records = csvReader!TSLayoutLong(data);
                auto rec = records.front;
                
                return Nullable!FileFormat(FileFormat.tradeStation);
            }
            if(fields.length == 6)
            {
                //probably TS
                auto records = csvReader!TSLayoutShort(data);
                auto rec = records.front;
                
                return Nullable!FileFormat(FileFormat.tradeStation);
            }
        }
        catch(CSVException e)
        {
            import std.stdio;

            stderr.writefln("Error guessing fileformat from '%s': %s", data, e);
        }

        return Nullable!FileFormat();
    }

    pure void opOpAssign(string op : "~")(in Bar rhs) @safe @nogc
    {
        if(this == Bar.init)
        {
            this = rhs;
            return;
        }

        this.time = rhs.time;
        this._volume += rhs.volume;
        if(this.high < rhs.high) this._high = rhs.high;
        if(this.low > rhs.low) this._low = rhs.low;
        this._close = rhs.close;
    }

    pure void opOpAssign(string op : "~", R)(R rhs) @safe @nogc
        if(isInputRange!R && is(ElementType!R : Bar))
    {
        foreach(b; rhs) this ~= b;
    }
}

unittest
{
    import std.exception;
    import std.datetime;
    import std.conv;
    import std.array;
    import std.stdio;
    import stockd.data;

    //Test NT format output
    Bar b = Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 100);
    assert(b.toString(FileFormat.ninjaTrader) == "20100302 050607;58.67865;58.82547;57.03316;57.73132;100");
    assert(to!string(b) == "20100302 050607;58.67865;58.82547;57.03316;57.73132;100");

    b = Bar(Date(2010, 3, 12), 58.678654, 58.825467, 57.033158, 57.7313214, 100);
    assert(b.toString(FileFormat.ninjaTrader) == "20100312;58.67865;58.82547;57.03316;57.73132;100");

    //Test TS format output
    b = Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 100);
    assert(b.toString(FileFormat.tradeStation) == "03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100");

    b = Bar(Date(2010, 3, 2), 58.678654, 58.825467, 57.033158, 57.7313214, 100);
    assert(b.toString(FileFormat.tradeStation) == "03/02/2010,58.67865,58.82547,57.03316,57.73132,100");

    //Test guessing FileFormat
    assert(Bar.guessFileFormat("20100302 050607;58.67865;58.82547;57.03316;57.73132;100") == FileFormat.ninjaTrader);
    assert(Bar.guessFileFormat("20100302;58.67865;58.82547;57.03316;57.73132;100") == FileFormat.ninjaTrader);
    assert(Bar.guessFileFormat("20100302;58.67865;58.82547;57.03316;57.73132") == FileFormat.ninjaTrader);
    assert(Bar.guessFileFormat("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100") == FileFormat.tradeStation);
    assert(Bar.guessFileFormat("03/02/2010,58.67865,58.82547,57.03316,57.73132,100") == FileFormat.tradeStation);
    assert(Bar.guessFileFormat("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100,500").isNull);
    assert(Bar.guessFileFormat("a;b;c;d;e;f").isNull);
    assert(Bar.guessFileFormat("a,b,c,d,e,f").isNull);
    assert(Bar.guessFileFormat("blablabla").isNull);

    //Test Bar.fromString
    b = Bar("20100302 050607;58.678654;58.825467;57.033158;57.7313214;100");
    assert(b == Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 100));
    assert(b.hasTOD);
    b = Bar("20100302 050607;58.678654;58.825467;57.033158;57.7313214");
    assert(b == Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 0));
    b = Bar("20100312;58.678654;58.825467;57.033158;57.7313214;100");
    assert(b == Bar(Date(2010, 3, 12), 58.678654, 58.825467, 57.033158, 57.7313214, 100));
    assert(!b.hasTOD);

    b = Bar("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100", FileFormat.tradeStation);
    assert(b == Bar(DateTime(2010, 3, 2, 5, 6, 0), 58.67865, 58.82547, 57.03316, 57.73132, 100));
    assert(b.hasTOD);
    b = Bar("03/02/2010,58.67865,58.82547,57.03316,57.73132,100", FileFormat.tradeStation);
    assert(b == Bar(Date(2010, 3, 2), 58.67865, 58.82547, 57.03316, 57.73132, 100));
    assert(!b.hasTOD);

    assertThrown(Bar("a;b;c;d;e;f"));
    assertThrown(Bar("a,b,c,d,e,f"));
    assertThrown(Bar("blablabla"));

    assertThrown(Bar("a;b;c;d;e;f", FileFormat.tradeStation));
    assertThrown(Bar("a,b,c,d,e,f", FileFormat.tradeStation));
    assertThrown(Bar("blablabla", FileFormat.tradeStation));

    //opOpAssign
    string barsText = r"20110715 205600;1.415;1.4152;1.41481;1.41481;11360
        20110715 205700;1.41486;1.41522;1.41477;1.41486;31010
        20110715 205800;1.41488;1.41506;1.41473;1.41502;15170
        20110715 205900;1.41489;1.41561;1.41486;1.41561;15280
        20110715 210000;1.41549;1.41549;1.41532;1.41532;540";
    auto expected = Bar("20110715 210000;1.41500;1.41561;1.41473;1.41532;73360");

    auto bars = marketData(barsText).array;
    b = bars[0];
    foreach(bar; bars[1..$])
        b ~= bar;

    assert(b == expected);

    b = bars[0];
    b ~= bars[1..$];
    assert(b == expected);

    b = Bar.init;
    b ~= expected;

    assert(b == expected);
}
