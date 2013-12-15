module stockd.conv.timeFrameConv;

import std.algorithm;
import std.datetime;
import std.exception;
import std.stdio;
import std.range;

import stockd.defs;

/**
 * Converts input Bar range to higher time frame range
 * 
 * For example can make h1 bars from m1 (hour TF from minute TF)
 */
template tfConv(uint factor)
{
    auto tfConv(Range)(Range r) if (isInputRange!Range && is(ElementType!Range : Bar))
    {
        return TimeFrameConv!(Range)(r, factor);
    }
}

private struct TimeFrameConv(T) if (isInputRange!T && is(ElementType!T : Bar))
{
    private T _input;
    private uint _factor;
    private Bar[] _buffer;
    private Bar[] _outBuffer;
    private TimeFrame _targetTF;
    private DateTime lastWaitTime;

    this(T input, uint factor, ubyte eodHour = 22)  //TODO: check if differ in summer and winter times - than session object should be passed
    {
        enforce(input.empty == false);
        enforce(factor > 0);

        this._input = input;
        this._factor = factor;

        //init TimeFrame
        _buffer ~= takeOne();
        if(!_input.empty)
        {
            _buffer ~= takeOne();
            _targetTF = TimeFrame(_buffer[1].time - _buffer[0].time) * factor;
        }

        //prepare next Bar
        popFront();
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
        if(_outBuffer.length > 1) 
        {
            _outBuffer = _outBuffer[1..$];
            return;
        }
        else _outBuffer = _outBuffer[0..0];

        if(_input.empty && _buffer.length>0)
        {
            //just return last bar
            if(_targetTF.origin >= Origin.day) _outBuffer ~= createBar!(Date)(_buffer, lastWaitTime.date);
            else _outBuffer ~= createBar!(DateTime)(_buffer, lastWaitTime);
        }
        else
        {
            //read next whole bar
            //TODO
            _input.popFront();
        }
    }

    private auto ref takeOne()
    {
        assert(_input.empty == false);

        auto res = _input.front();
        _input.popFront();

        return res;
    }
}

unittest
{
    import std.algorithm;
    import std.conv;

    // Test M1 to M5
    string barsText = r"20110715 205500;1.4154;1.41545;1.41491;1.41498;33450
        20110715 205600;1.415;1.4152;1.41481;1.41481;11360
        20110715 205700;1.41486;1.41522;1.41477;1.41486;31010
        20110715 205800;1.41488;1.41506;1.41473;1.41502;15170
        20110715 205900;1.41489;1.41561;1.41486;1.41561;15280
        20110715 210000;1.41549;1.41549;1.41532;1.41532;540";

    string[] expected = 
        [
            "20110715 205500;1.4154;1.41545;1.41491;1.41498;33450",
            "20110715 210000;1.415;1.41561;1.41473;1.41532;73360"
        ];

    //auto bars = barsText.splitter('\n').map!(b => Bar.fromString(b));
    auto bars = readBars(barsText).tfConv!(5);

    int i;
    foreach(b; bars)
    {
        writefln("%s -> %s", i, b);
        assert(expected[i++] == to!string(b));
    }
    assert(i == 2);

    // Test M5 to M5 - should return the same data as input
    barsText = "20110715 205500;1.4154;1.41545;1.41491;1.41498;33450\n"
        ~ "20110715 210000;1.415;1.41561;1.41473;1.41532;73360";
    
    expected = 
    [
        "20110715 205500;1.4154;1.41545;1.41491;1.41498;33450",
        "20110715 210000;1.415;1.41561;1.41473;1.41532;73360"
    ];
    
    //auto bars = barsText.splitter('\n').map!(b => Bar.fromString(b));
    bars = readBars(barsText).tfConv!(1);
    
    i = 0;
    foreach(b; bars)
    {
        writefln("%s -> %s", i, b);
        assert(expected[i++] == to!string(b));
    }
    assert(i == 2);
}