module stockd.defs.bar;

import stockd.defs.common;
import std.datetime;

enum FileFormat {ninjaTrader, tradeStation, guess}

pure @safe private auto tryReadBar(FileFormat ff)(in string data, out Bar bar)
    if(ff != FileFormat.guess)
{
    import std.stdio;

    static if(ff == FileFormat.ninjaTrader) enum delimiter = ';';
    else static if(ff == FileFormat.tradeStation) enum delimiter = ',';

    short year;
    byte month, day, hour, min, sec;
    double open, high, low, close;
    bool hasTOD;
    size_t vol;

    auto isNum(in char ch) { return ch >= '0' && ch <= '9'; }
    pure @safe @nogc nothrow auto readNum(T)(in string data, ref int idx, out T output)
    {
        foreach(i, n; data)
        {
            if(!isNum(n)) { idx++; return i; }

            output *= 10;
            output += n - '0';
            idx++;
        }

        return data.length;
    }

    pure @safe nothrow auto readDouble(in string data, ref int idx, out double output)
    {
        enum powersOf10 = [
            1.,    
            10.,
            100.,
            1.0e3,
            1.0e4,
            1.0e5,
            1.0e6,
            1.0e7,
            1.0e8,
            1.0e9
        ];

        output = 0;

        int _mantisa;
        int _fraction;

        bool prec;
        byte precIdx;
        foreach(n; data)
        {
            if(n == delimiter) { idx++; break; }
            if(n != '.')
            {
                if(!isNum(n))
                {
                    trustedPureDebugCall!writefln("Invalid character '%s' in %s", n, data);
                    return false;
                }

                if(!prec)
                {
                    _mantisa *= 10;
                    _mantisa += n - '0';
                }
                else
                {
                    _fraction *= 10;
                    _fraction += n - '0';
                    precIdx++;
                }
            }
            else prec = true;

            idx++;
        }

        output = _mantisa +  cast(double)(_fraction) / powersOf10[precIdx];

        return true;
    }

    pure @safe nothrow auto forceChar(in string data, ref int idx, char ch)
    {
        if(data[idx] != ch)
        {
            trustedPureDebugCall!writefln("Invalid character '%s' in %s", ch, data);
            return false;
        }

        idx++;
        return true;
    }

    int idx;
    while(!isNum(data[idx])) 
    {
        idx++; //find first number
        if(idx == data.length)
        {
            trustedPureDebugCall!writefln("Number not found in '%s'", data);
            return false;
        }
    }

    static if(ff == FileFormat.ninjaTrader)
    {
        if(readNum(data[idx..idx+4], idx, year) != 4) return false;
        if(readNum(data[idx..idx+2], idx, month) != 2) return false;
        if(readNum(data[idx..idx+2], idx, day) != 2) return false;

        if(data[idx] == ' ')
        {
            hasTOD = true;
            idx++;
            if(readNum(data[idx..idx+2], idx, hour) != 2) return false;
            if(readNum(data[idx..idx+2], idx, min) != 2) return false;
            if(readNum(data[idx..idx+2], idx, sec) != 2) return false;
        }

        if(!forceChar(data, idx, delimiter)) return false;
    }
    else static if(ff == FileFormat.tradeStation)
    {
        //read MM/dd/yyyy
        if(readNum(data[idx..idx+2], idx, month) != 2) return false;
        if(!forceChar(data, idx, '/')) return false;
        if(readNum(data[idx..idx+2], idx, day) != 2) return false;
        if(!forceChar(data, idx, '/')) return false;
        if(readNum(data[idx..idx+4], idx, year) != 4) return false;
        if(!forceChar(data, idx, delimiter)) return false;

        bool isDouble;
        for(int i=idx; i<data.length; i++)
        {
            if(isNum(data[i])) continue;
            else if(data[i] == '.') { isDouble = true; break; }
            else if(data[i] == delimiter) break;
            else return false;
        }

        if(!isDouble)
        {
            if(data[idx+4] != delimiter) return false;

            //read hhmm
            hasTOD = true;
            if(readNum(data[idx..idx+2], idx, hour) != 2) return false;
            if(readNum(data[idx..idx+2], idx, min) != 2) return false;
            if(!forceChar(data, idx, delimiter)) return false;
        }
    }

    if(!readDouble(data[idx..$], idx, open)) return false;
    if(!readDouble(data[idx..$], idx, high)) return false;
    if(!readDouble(data[idx..$], idx, low)) return false;
    if(!readDouble(data[idx..$], idx, close)) return false;
    if(idx != data.length) if(!readNum(data[idx..$], idx, vol)) return false;
    if(idx != data.length) return false;

    bar = hasTOD ? Bar(DateTime(year, month, day, hour, min, sec), open, high, low, close, vol)
        : Bar(Date(year, month, day), open, high, low, close, vol);

    return true;
}

unittest
{
    import std.stdio;

    Bar expected = Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.67865, 58.82547, 57.03316, 57.73132, 100);

    Bar b;
    assert(tryReadBar!(FileFormat.ninjaTrader)("20100302 050607;58.67865;58.82547;57.03316;57.73132;100", b));
    assert(tryReadBar!(FileFormat.ninjaTrader)("20100302 050607;58.67865;58.82547;57.03316;57.73132;100;", b));
    assert(b == expected);
    expected = Bar(DateTime(2010, 3, 2, 5, 6, 0), 58.67865, 58.82547, 57.03316, 57.73132, 100);
    assert(tryReadBar!(FileFormat.tradeStation)("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100,", b));
    assert(tryReadBar!(FileFormat.tradeStation)("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100", b));
    assert(b == expected);
    expected = Bar(Date(2010, 3, 2), 58.67865, 58.82547, 57.03316, 57.73132, 100);
    assert(tryReadBar!(FileFormat.ninjaTrader)("20100302;58.67865;58.82547;57.03316;57.73132;100", b));
    assert(b == expected);
    assert(tryReadBar!(FileFormat.tradeStation)("03/02/2010,58.67865,58.82547,57.03316,57.73132,100", b));
    assert(b == expected);

    //invalid bars
    assert(!tryReadBar!(FileFormat.ninjaTrader)("20100302050607;58.67865;58.82547;57.03316;57.73132;100", b));
    assert(!tryReadBar!(FileFormat.ninjaTrader)("20100302 050607;58,67865;58.82547;57.03316;57.73132;100", b));
    assert(!tryReadBar!(FileFormat.ninjaTrader)("20100302 050607;58,67865;58.82547;57.03316;57.73132,100", b));
    assert(!tryReadBar!(FileFormat.ninjaTrader)("invalid", b));

    assert(!tryReadBar!(FileFormat.tradeStation)("03/02/2010,0506;58.67865,58.82547,57.03316,57.73132,100", b));
    assert(!tryReadBar!(FileFormat.tradeStation)("03/02/2010,050602,58.67865,58.82547,57.03316,57.73132,100", b));
    assert(!tryReadBar!(FileFormat.tradeStation)("invalid", b));
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
pure @safe FileFormat guessFileFormat(in string data)
{
    Bar b;
    if(tryReadBar!(FileFormat.ninjaTrader)(data, b)) return FileFormat.ninjaTrader;
    if(tryReadBar!(FileFormat.tradeStation)(data, b)) return FileFormat.tradeStation;

    return FileFormat.guess;
}

unittest
{
    //Test guessing FileFormat
    assert(guessFileFormat("20100302 050607;58.67865;58.82547;57.03316;57.73132;100") == FileFormat.ninjaTrader);
    assert(guessFileFormat("20100302;58.67865;58.82547;57.03316;57.73132;100") == FileFormat.ninjaTrader);
    assert(guessFileFormat("20100302;58.67865;58.82547;57.03316;57.73132") == FileFormat.ninjaTrader);
    assert(guessFileFormat("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100") == FileFormat.tradeStation);
    assert(guessFileFormat("03/02/2010,58.67865,58.82547,57.03316,57.73132,100") == FileFormat.tradeStation);
    assert(guessFileFormat("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100,500") == FileFormat.guess);
    assert(guessFileFormat("a;b;c;d;e;f") == FileFormat.guess);
    assert(guessFileFormat("a,b,c,d,e,f") == FileFormat.guess);
    assert(guessFileFormat("blablabla") == FileFormat.guess);
}

/**
 * Defines BAR structure
 */
struct Bar
{
    import std.datetime;
    import std.format;
    import std.range;

    private bool _hasTOD;
    private DateTime _time;
    @property @safe @nogc pure nothrow public DateTime time() const { return _time; }
    @property @safe @nogc pure nothrow public void time(DateTime value) { _time = value; _hasTOD = true; }
    @property @safe pure nothrow public void time(Date value) { _time = DateTime(value); _hasTOD = false; }

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
    pure @safe @nogc nothrow this(DateTime time, double open, double high, double low, double close, ulong volume = 0) @nogc
    {
        this._time = time;
        this._open = open;
        this._high = high;
        this._low = low;
        this._close = close;
        this._volume = volume;
        this._hasTOD = true;
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
    pure @safe nothrow this(Date date, double open, double high, double low, double close, ulong volume = 0)
    {
        this._time = DateTime(date);
        this._open = open;
        this._high = high;
        this._low = low;
        this._close = close;
        this._volume = volume;
        this._hasTOD = false;
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
    pure this(in string data, FileFormat ff = FileFormat.guess)
    {
        //TODO: add possibility to specify source TimeZone so we can convert input datetime to internal UTC

        if(ff == FileFormat.guess)
        {
            auto fileFormat = guessFileFormat(data);
            if(fileFormat == FileFormat.guess) throw new Exception("Unknown input data: " ~ data);
            ff = fileFormat;
        }

        final switch(ff)
        {
            case(FileFormat.ninjaTrader):
                Bar b;
                if(!tryReadBar!(FileFormat.ninjaTrader)(data, b)) throw new Exception("This is not a NinjaTrader data format: " ~ data);
                this = b;
                break;
            case(FileFormat.tradeStation):
                Bar b;
                if(!tryReadBar!(FileFormat.tradeStation)(data, b)) throw new Exception("This is not a TradeStation data format: " ~ data);
                this = b;
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
    pure nothrow @property auto ohlc() const
    {
        return [this._open, this._high, this._low, this._close];
    }

    pure void opOpAssign(string op : "~")(in Bar rhs) @safe @nogc
    {
        if(this == Bar.init)
        {
            this = rhs;
            return;
        }
        
        assert(this._hasTOD == rhs._hasTOD);
        
        this._time = rhs.time;
        this._hasTOD = rhs._hasTOD;
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

    /**
     * Writes the formated Bar to specified sink
     * 
     * To specify type of output, custom format specifiers can be used:
     *      %n: Ninja Trader format
     *      %t: Trade Station format
     */
    void toString(scope void delegate(const(char)[]) sink, FormatSpec!char fmt) const
    {
        switch(fmt.spec)
        {
            case 't': //tradestation
                if(_hasTOD)
                {
                    formattedWrite(sink, "%02d/%02d/%d,%02d%02d,%.5f,%.5f,%.5f,%.5f,%d", 
                                  time.month, time.day, time.year, time.hour, time.minute,
                                  _open, _high, _low, _close, _volume);
                }
                else
                {
                    formattedWrite(sink, "%02d/%02d/%d,%.5f,%.5f,%.5f,%.5f,%d", 
                              time.month, time.day, time.year,
                              _open, _high, _low, _close, _volume);
                }
                break;
            case 'n': //ninja trader or default
            default:
                if(_hasTOD)
                {
                    formattedWrite(sink, "%s %s;%.5f;%.5f;%.5f;%.5f;%d", 
                                   time.date.toISOString, time.timeOfDay.toISOString,
                                   _open, _high, _low, _close, _volume);
                }
                else
                {
                    formattedWrite(sink, "%s;%.5f;%.5f;%.5f;%.5f;%d", 
                                   time.date.toISOString,
                                   _open, _high, _low, _close, _volume);
                }
                break;
        }
    }

    /**
     * Gets CSV format string of the BAR in NT format
     * 
     * NT format is:
     * yyyyMMdd HHmmss;open price;high price;low price;close price;volume
     * or
     * yyyyMMdd;open price;high price;low price;close price;volume
     */
    string toString() const
    {
        import std.array : appender;

        auto writer = appender!string;
        formattedWrite(writer, "%n", this);
        return writer.data;
    }

    /**
     * Gets CSV format string of the BAR in NT format
     * 
     * NT format is:
     * yyyyMMdd HHmmss;open price;high price;low price;close price;volume
     * or
     * yyyyMMdd;open price;high price;low price;close price;volume
     */
    string toString(FileFormat ff = FileFormat.ninjaTrader) const
    {
        import std.array : appender;

        string formatStr;
        final switch(ff)
        {
            case FileFormat.tradeStation:
                formatStr = "%t";
                break;
            case FileFormat.ninjaTrader:
            case FileFormat.guess:
                formatStr = "%n";
                break;
        }
        
        auto writer = appender!string;
        formattedWrite(writer, formatStr, this);
        return writer.data;
    }
}

/**
 * Template which defines bar literal
 */
template bar(string s)
{
    enum bar = Bar(s);
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

    //Test Bar.fromString
    b = Bar("20100302 050607;58.678654;58.825467;57.033158;57.7313214;100");
    assert(b == Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 100));
    assert(b._hasTOD);
    b = Bar("20100302 050607;58.678654;58.825467;57.033158;57.7313214");
    assert(b == Bar(DateTime(2010, 3, 2, 5, 6, 7), 58.678654, 58.825467, 57.033158, 57.7313214, 0));
    b = Bar("20100312;58.678654;58.825467;57.033158;57.7313214;100");
    assert(b == Bar(Date(2010, 3, 12), 58.678654, 58.825467, 57.033158, 57.7313214, 100));
    assert(!b._hasTOD);

    b = Bar("03/02/2010,0506,58.67865,58.82547,57.03316,57.73132,100", FileFormat.tradeStation);
    assert(b == Bar(DateTime(2010, 3, 2, 5, 6, 0), 58.67865, 58.82547, 57.03316, 57.73132, 100));
    assert(b._hasTOD);
    b = Bar("03/02/2010,58.67865,58.82547,57.03316,57.73132,100", FileFormat.tradeStation);
    assert(b == Bar(Date(2010, 3, 2), 58.67865, 58.82547, 57.03316, 57.73132, 100));
    assert(!b._hasTOD);

    auto b2 = b;
    b2 ~= b;
    assert(!b._hasTOD);
    assert(b2 == Bar("03/02/2010,58.67865,58.82547,57.03316,57.73132,200", FileFormat.tradeStation));

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

    //test bar literal
    assert(bar!"20110715 210000;1.41500;1.41561;1.41473;1.41532;73360" == expected);
}
