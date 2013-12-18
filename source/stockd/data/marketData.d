module stockd.data.marketdata;

import std.stdio;
import std.range;
import std.traits;

import stockd.defs;

/**
 * This class works as an input range of BARs
 * 
 * It accepts file, string and inputRange!string as an input.
 * 
 * It reads input line by line and tries to construct Bar struct from it. It validates input so invalid bars are ignored.
 * When initialized, it can guess source TF (from first bars) and check forthcomming to be within the same range
 * 
 * TODO: when done, remove readBars template with this
 */
class MarketData(T) 
    if(is(T == File) || is(isSomeString!T) || (isInputRange!T && is(isSomeString!(ElementType!T))))
{
    private InputRange!(char[]) _input;
    private Bar[] _outBuffer;
    private Bar[] _tfGuessBuffer;
    private string _symbol;
    private TimeFrame _timeFrame;
    private FileFormat _fileFormat = FileFormat.guess;

    @property @safe pure nothrow auto timeFrame() const
    {
        return _timeFrame;
    }

    /// Constructor for file input
    this(T input, const string symbol)
    {
        static if(is(T == File))
        {
            //make input range from file
            _input = inputRangeObject(input.byLine!(char, char));
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
    }

    @property bool empty()
    {
        return _outBuffer.empty;
    }
    
    @property auto ref front()
    {
        assert(!_outBuffer.empty);
        
        return _outBuffer[0];
    }
    
    void popFront()
    {
        assert(false, "not implemented yet");
    }

    private auto ref takeOne()
    {
        assert(_input.empty == false || _tfGuessBuffer.empty == false);
        
        if(_tfGuessBuffer.length > 0 && _timeFrame != TimeFrame.init)
        {
            //first return from TF guess buffer
            auto next = _tfGuessBuffer.front;
            _tfGuessBuffer.popFront();
            return next;
        }
        
        auto res = _input.front;
        _input.popFront();

        if(_fileFormat == FileFormat.guess)
        {
            //not yet known file format - so guess it from input data
            for(uint tries = 3; tries>0; --tries)
            {
                //this skips also the possible CSV header - ok with me, guessing should work ok without it (at least in my usecases)
                auto ff = Bar.guessFileFormat(cast(string)res);
                if(!ff.isNull)
                {
                    _fileFormat = ff;
                    break;
                }
                if(!_input.empty) //read next line
                {
                    res = _input.front;
                    _input.popFront();
                }
            }
            if(_fileFormat == FileFormat.guess) throw new Exception("Cannot determine input data format");
        }
        
        return Bar.fromString(cast(string)res, _fileFormat);
    }
}

