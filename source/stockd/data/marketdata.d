module stockd.data.marketdata;

import std.stdio;
import std.range;
import stockd.defs;
import S = stockd.data.symbol;

/**
 * Helper function to create MarketData range
 */
auto marketData(T)(T input, in S.Symbol symbol = S.Symbol.init, TimeFrame tf = TimeFrame.init)
    if(isSomeString!T || is(T == File) || (isInputRange!T && (isSomeString!(ElementType!T) || is(ElementType!T == Bar))))
{
    import std.typecons;
    import std.algorithm;

    static if(isInputRange!T && is(ElementType!T == Bar))
    {
        //just return struct
        return MarketData!T(input, symbol, tf);
    }
    else
    {
        static if(is(T == File))
        {
            //make input range from file
            auto _input = input.byLine().map!"a.idup";
        }
        else static if(isSomeString!T)
        {
            //read input by lines
            import std.algorithm;

            auto _input = input.splitter('\n');
        }

        //guess input format
        FileFormat ff;
        while((ff = guessFileFormat(_input.front)) == FileFormat.unknown)
        {
            _input.popFront();
        }

        debug trustedPureDebugCall!writeln("Detected file format: ", ff);
        
        import std.algorithm;
        
        return marketData(_input.map!(a => Bar(a, ff)), symbol, tf);
    }
}

/**
 * This class works as an input range of BARs
 * 
 * It reads input line by line and tries to construct Bar struct from it. It validates input so invalid bars are ignored.
 * When initialized, it can guess source TF (from first bars) and check forthcomming to be within the same range
 */
struct MarketData(T) 
    if(isInputRange!T && is(ElementType!T == Bar))
{
    enum guessNumBar = 10;
    
    private InputRange!(Bar) _input;
    private S.Symbol _symbol;
    private TimeFrame _timeFrame;

    @nogc @property @safe pure nothrow public auto symbol() const
    {
        return _symbol;
    }

    @nogc @property @safe pure nothrow auto timeFrame() const
    {
        return _timeFrame;
    }

    @disable this();

    /// Constructor for file input
    this(T input, in S.Symbol symbol = S.Symbol.init, TimeFrame tf = TimeFrame.init)
    {
        import std.array;
        import std.range;
        import std.exception : enforce;
        import std.traits;
        import std.algorithm;

        enforce(input.empty == false);

        if(tf == TimeFrame.init)
        {
            //guess time frame from input
            static if(isArray!T)
            {
                _timeFrame = guessTimeFrame(input[0..min(guessNumBar, input.length)]);
                _input = inputRangeObject(input);
            }
            else
            {
                auto tfGuessArray = take(&input, guessNumBar).array();
                _timeFrame = guessTimeFrame(tfGuessArray);
                
                //as part of input range was consumed for TF guessing, chain guess buffer with the input range
                _input = inputRangeObject(chain(tfGuessArray, input));
            }
        }
        else
        {
            this._timeFrame = tf;
            _input = inputRangeObject(input);
        }

        this._symbol = symbol;
    }

    @property bool empty()
    {
        return _input.empty;
    }
    
    @property auto ref front()
    {
        assert(!_input.empty);
        
        return _input.front;
    }
    
    void popFront()
    {
        assert(!empty);
        _input.popFront();
    }
}

unittest
{
    import std.range;
    import std.array;
    import std.traits;
    import std.stdio;

    assert(isInputRange!(MarketData!(Bar[])));

    string barsText = r"20110715 205500;1.4154;1.41545;1.41491;1.41498;33450
        20110715 205600;1.415;1.4152;1.41481;1.41481;11360
        20110715 205700;1.41486;1.41522;1.41477;1.41486;31010
        20110715 205800;1.41488;1.41506;1.41473;1.41502;15170
        20110715 205900;1.41489;1.41561;1.41486;1.41561;15280
        20110715 210000;1.41549;1.41549;1.41532;1.41532;540";

    Bar[] expected = [
        bar!"20110715 205500;1.4154;1.41545;1.41491;1.41498;33450",
        bar!"20110715 205600;1.415;1.4152;1.41481;1.41481;11360",
        bar!"20110715 205700;1.41486;1.41522;1.41477;1.41486;31010",
        bar!"20110715 205800;1.41488;1.41506;1.41473;1.41502;15170",
        bar!"20110715 205900;1.41489;1.41561;1.41486;1.41561;15280",
        bar!"20110715 210000;1.41549;1.41549;1.41532;1.41532;540"
    ];

    auto data = marketData(barsText).array;
    assert(data == expected);

    auto data2 = marketData(inputRangeObject(data)).array;
    assert(data2 == expected);

    auto data3 = marketData(data2).array;
    assert(data3 == expected);
}
