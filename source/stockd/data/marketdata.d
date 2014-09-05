module stockd.data.marketdata;

import std.algorithm;
import std.stdio;
import std.range;
import std.traits;

import stockd.defs;

/**
 * Helper function to create MarketData range
 */
auto marketData(T)(T input, in string symbol)
    if(is(T == File) || is(isSomeString!T) || (isInputRange!T && is(isSomeString!(ElementType!T))))
{
    return MarketData!T(input, symbol);
}

/**
 * This class works as an input range of BARs
 * 
 * It accepts file, string and inputRange!string as an input.
 * 
 * It reads input line by line and tries to construct Bar struct from it. It validates input so invalid bars are ignored.
 * When initialized, it can guess source TF (from first bars) and check forthcomming to be within the same range
 * 
 * TODO: when done, remove readBars template with this
 * TODO: change to struct
 */
struct MarketData(T) 
    if(is(T == File) || is(isSomeString!T) || (isInputRange!T && is(isSomeString!(ElementType!T))))
{
    private File.ByLine!(char, char) _input;
    private Bar _current;
    private Bar[] _tfGuessBuffer;
    private string _symbol;
    private TimeFrame _timeFrame;
    private FileFormat _fileFormat = FileFormat.guess;

    @property @safe @nogc pure nothrow auto timeFrame() const
    {
        return _timeFrame;
    }

    @disable this();

    /// Constructor for file input
    this(T input, in string symbol)
    {
        static if(is(T == File))
        {
            //make input range from file
            //_input = inputRangeObject(input.byLine().map!(a=>cast(string)a));
            _input = input.byLine();
        }
        else if(isSomeString!T)
        {
            //make input range from string
            _input = input.splitLines();
        }
        else
        {
            //just use the input
            this._input = input;
        }
        this._symbol = symbol;
        popFront();
    }

    @property bool empty() @safe
    {
        return _input.empty;
    }
    
    @property auto ref front()
    {
        assert(!_input.empty);
        
        return _current;
    }
    
    void popFront()
    {
        assert(false, "not implemented yet");
    }

    private auto takeOne()
    {
        assert(_input.empty == false || _tfGuessBuffer.empty == false);
        
        if(_tfGuessBuffer.length > 0 && _timeFrame != TimeFrame.init)
        {
            //first return from TF guess buffer
            auto next = _tfGuessBuffer.moveFront;
            return next;
        }
        
        auto res = _input.moveFront;

        if(_fileFormat == FileFormat.guess)
        {
            //not yet known file format - so guess it from input data
            for(uint tries = 3; tries>0; --tries)
            {
                //this skips also the possible CSV header - ok with me, guessing should work ok without it (at least in my usecases)
                auto ff = Bar.guessFileFormat(res);
                if(!ff.isNull)
                {
                    _fileFormat = ff;
                    break;
                }
                if(!_input.empty) //read next line
                {
                    res = _input.moveFront;
                }
            }
            if(_fileFormat == FileFormat.guess) throw new Exception("Cannot determine input data format");
        }
        
        return Bar(cast(string)res, _fileFormat);
    }
}

unittest
{

}