module stockd.conv.tfconv;

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
    private Bar[] _tfGuessBuffer;
    private Bar[] _outBuffer;
    private TimeFrame _targetTF = TimeFrame.init;
    private DateTime _lastWaitTime;
    private ubyte _eodHour;

    /**
     * Params:
     *  input - input bar range
     *  factor - time frame multiplyer
     *  eodHour - hour at which trading session ends in UTC time
     */
    this(T input, uint factor, ubyte eodHour = 22)  //TODO: check if differ in summer and winter times - than session object should be passed (it would be more generic)
    {
        enforce(input.empty == false);
        enforce(factor > 0);

        this._input = input;
        this._factor = factor;

        //init TimeFrame - //TODO: check more than 2 bars? add input param to set it directly?
        _tfGuessBuffer ~= takeNext();
        if(!_input.empty)
        {
            _tfGuessBuffer ~= takeNext();
            _targetTF = TimeFrame(_tfGuessBuffer[1].time - _tfGuessBuffer[0].time) * factor;
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
            _outBuffer.popFront();
            return;
        }
        else _outBuffer = null;

        //read from input till we have next Bar or input is empty
        while(!_input.empty || !_tfGuessBuffer.empty)
        {
            auto next = takeNext();
            auto waitTime = nextValidTime(next);

            if (next.time > _lastWaitTime)
            {
                assert(_lastWaitTime < waitTime);

                //add one from buffer if there are some bars waiting
                if(_buffer.length > 0) _outBuffer ~= createBarFromBuffer();

                if (next.time == waitTime)
                {
                    //just return this one
                    _outBuffer ~= next;
                }
                else _buffer ~= next; //add to buffer and wait for next
            }
            else
            {
                assert(_lastWaitTime == waitTime);

                //add to buffer
                _buffer ~= next;

                if(next.time == _lastWaitTime)
                {
                    //we've got next with exact time! => create output bar and clear buffer
                    _outBuffer ~= createBarFromBuffer();
                }
            }
            
            _lastWaitTime = waitTime;
            //filter out weekend bars from input
            //TODO: not sure if this should be here at all -> input validation in marketData range?
            if (_targetTF.origin == Origin.day && _factor == 1 && _outBuffer.length > 0)
            {
                _outBuffer = _outBuffer.filter!(b => b.time.dayOfWeek != DayOfWeek.sun && b.time.dayOfWeek != DayOfWeek.sat).array;
            }
            if(_outBuffer.length > 0) break; //we have the next bar
        }

        if(_outBuffer.length == 0 && _buffer.length > 0)
        {
            //return last bars from buffer
            _outBuffer ~= createBarFromBuffer();
        }
    }

    private auto ref takeNext()
    {
        assert(_input.empty == false || _tfGuessBuffer.empty == false);

        if(_tfGuessBuffer.length > 0 && _targetTF != TimeFrame.init)
        {
            //first return from TF guess buffer
            auto next = _tfGuessBuffer.front;
            _tfGuessBuffer.popFront;
            return next;
        }

        auto res = _input.front;
        _input.popFront;

        return res;
    }

    /// gets next time we wait for from the current bar
    private DateTime nextValidTime(ref Bar bar)
    {
        final switch(_targetTF.origin)
        {
            case Origin.minute:
                uint rest = bar.time.minute % _factor;
                if(rest == 0) return bar.time;// + dur!"minutes"(_factor);
                else return bar.time + dur!"minutes"(_factor - rest);
            case Origin.hour:
                auto next = bar.time;
                if (next.minute != 0) next += dur!"minutes"(60 - next.minute);
                uint rest = next.hour % _factor;
                if (rest == 0) return next;
                else return next + dur!"hours"(_factor - rest);
            case Origin.day:
                auto next = bar.time;
                if (next.minute != 0) next += dur!"minutes"(60 - next.minute);
                if (next.hour < _eodHour) next += dur!"hours"(_eodHour - next.hour);
                if (next.hour > _eodHour) next += dur!"hours"(24 - next.hour + _eodHour);
                if (_factor == 1 || next.dayOfWeek == DayOfWeek.fri)
                {
                    if (bar.time == next && bar.time.dayOfWeek == DayOfWeek.sun)
                    {
                        //ensure usage of first week session bar
                        bar.time += dur!"minutes"(1);
                        return nextValidTime(bar);
                    }
                    return next;
                }
                //set to friday
                if (next.dayOfWeek == DayOfWeek.sat) return next + dur!"days"(6);
                return next + dur!"days"(DayOfWeek.fri - next.dayOfWeek);
            case Origin.week:
                return bar.time;
        }
    }

    auto createBarFromBuffer()
    {
        scope(exit)
        {
            //clear buffer
            _buffer = null;
        }

        if(_targetTF.origin >= Origin.day) return createBar!(Date)(_buffer, _lastWaitTime.date);
        else return createBar!(DateTime)(_buffer, _lastWaitTime);
    }
}

auto guessTimeFrame(R)(in R data)
    if(isInputRange!R && is(ElementType!R : Bar))
{
    assert(!data.empty);

    ElementType!R last = data.front;
    auto res = TimeFrame.init;
    foreach(b; data)
    {
        auto diff = b.time - last.time;
        if(diff > TimeFrame.init && (res == 0 || res > diff))
           res = diff;

        last = b;
    }
    return res;
}

//guessTimeFrame
unittest
{
    auto data = readBars(
        r"20110715 205500;1.41540;1.41545;1.41491;1.41498;33450
        20110715 210000;1.41500;1.41561;1.41473;1.41532;73360"
        ).array;
    assert(guessTimeFrame(data) == 5);

    data = readBars(
        r"20110715 205500;1.41540;1.41545;1.41491;1.41498;33450
        20110715 205500;1.41500;1.41561;1.41473;1.41532;73360"
        ).array;
    assert(guessTimeFrame(data) == TimeFrame.init);

    data = readBars(
        r"20110715 205500;1.41540;1.41545;1.41491;1.41498;33450"
        ).array;
    assert(guessTimeFrame(data) == TimeFrame.init);

    data = readBars(
        r"20110715 205500;1.41540;1.41545;1.41491;1.41498;33450
        20110715 215500;1.41500;1.41561;1.41473;1.41532;73360"
        ).array;
    assert(guessTimeFrame(data) == 60);
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

    auto expected = readBars("20110715 205500;1.41540;1.41545;1.41491;1.41498;33450\n"
        ~"20110715 210000;1.41500;1.41561;1.41473;1.41532;73360").array;

    auto bars = readBars(barsText).tfConv!(5);

    writeln("Test M1 -> M5");
    int i;
    foreach(b; bars)
    {
//        writefln("%s -> %s", i, b);
//        writefln("%s -> %s expected", i, expected[i]);
        assert(expected[i++] == b);
    }
    assert(i == 2);

    // Test M5 to M5 - should return the same data as input
    barsText = "20110715 205500;1.4154;1.41545;1.41491;1.41498;33450\n"
        ~ "20110715 210000;1.415;1.41561;1.41473;1.41532;73360";
    
    //auto bars = barsText.splitter('\n').map!(b => Bar.fromString(b));
    bars = readBars(barsText).tfConv!(1);

    writeln("Test M5 -> M5");
    i = 0;
    foreach(b; bars)
    {
//        writefln("%s -> %s", i, b);
//        writefln("%s -> %s expected", i, expected[i]);
        assert(expected[i++] == b);
    }
    assert(i == 2);

    //TODO: Add more tests - more time frames, tests with invalid input, etc
}
