module stockd.defs.timeFrame;

import std.conv;
import std.stdio;
import std.string;
import core.time;

enum Origin {minute, hour, day, week}

/**
 * Represents time interval between bars
 * 
 * Can represent following time frames:
 *      minute
 *      hour
 *      day
 *      week
 */
struct TimeFrame
{
    private uint _minutes;

    /// Gets TF total minutes
    pure nothrow @property auto totalMinutes() const
    {
        return _minutes;
    }

    /// Gets TF total hours
    pure nothrow @property auto totalHours() const
    {
        return _minutes / 60;
    }

    /// Gets TF total days
    pure nothrow @property auto totalDays() const
    {
        return _minutes / (60*24);
    }

    /// Gets TF total weeks
    pure nothrow @property auto totalWeeks() const
    {
        return _minutes / (60*24*7);
    }

    pure nothrow @property auto origin() const
    {
        if(_minutes >= 60 * 24 * 7) return Origin.week;
        else if(_minutes >= 60 * 24) return Origin.day;
        else if(_minutes >= 60 ) return Origin.hour;
        return Origin.minute;
    }

    pure invariant()
    {
        if(_minutes >= 60 * 24 * 7) assert(_minutes % (60 * 24 * 7) == 0);  //Wx
        else if(_minutes >= 60 * 24) assert(_minutes % (60 * 24) == 0);   // Dx
        else if(_minutes >= 60 ) assert(_minutes % 60 == 0);  // Hx
    }

    pure nothrow this(uint minutes)
    {
        this._minutes = minutes;
    }

    pure this(string minutes)
    {
        this._minutes = parse(minutes);
    }

    pure this(Duration duration)
    {
        this._minutes = to!uint(duration.total!"minutes");
    }

    pure toString() const
    {
        if(_minutes < 60) return format("M%s", _minutes);
        if(_minutes < 60 * 24) return format("H%s", _minutes / 60);
        if(_minutes < 60 * 24 * 7) return format("D%s", _minutes / (60*24));
        return format("W%s", _minutes / (60*24*7));
    }

    pure private uint parse(in string text)
    {
        assert(text.length >= 2);

        switch(text[0])
        {
            case 'm':
            case 'M':
                return to!int(text[1..$]);
            case 'h':
            case 'H':
                return to!int(text[1..$]) * 60;
            case 'd':
            case 'D':
                return to!int(text[1..$]) * 60 * 24;
            case 'w':
            case 'W':
                return to!int(text[1..$]) * 60 * 24 * 7;
            default:
                throw new Exception("Invaild format of TimeFrame: " ~ text);
        }
    }

    pure ref TimeFrame opAssign(in string text)
    {
        this._minutes = parse(text);
        return this;
    }

    pure ref TimeFrame opAssign(in uint minutes)
    {
        this._minutes = minutes;
        return this;
    }

    pure ref TimeFrame opAssign(in Duration duration)
    {
        this._minutes = to!uint(duration.total!"minutes");
        return this;
    }

    pure ref TimeFrame opOpAssign(string op)(in int mul)
        if(op == "*")
    {
        this._minutes *= mul;
        return this;
    }

    pure bool opEquals(in string text)
    {
        return this._minutes == parse(text);
    }
    pure bool opEquals(in int minutes)
    {
        return this._minutes == minutes;
    }

    pure bool opEquals(in Duration duration)
    {
        return this._minutes == duration.total!"minutes";
    }

    /// implicit conversion to uint
    alias totalMinutes this;
}

unittest
{
    import core.exception;
    import std.exception;

    assert(TimeFrame(5) == 5);
    assert(TimeFrame(60) == 60);
    assertThrown!AssertError(TimeFrame(61));

    assert(TimeFrame(5) == "M5");
    assert(TimeFrame(60) == "H1");
    assert(TimeFrame(60*24) == "D1");
    assert(TimeFrame(60*48) == "D2");
    assert(TimeFrame(60*24*7) == "W1");

    TimeFrame tf = "M1";
    assert(tf == 1);
    assert((tf = "M5") == 5);

    assert(tf == dur!"minutes"(5));
    assert((tf = "H5") == dur!"hours"(5));

    assert((tf = dur!"minutes"(5)) == 5);

    assert(TimeFrame(dur!"minutes"(5)) == 5);
    assert(TimeFrame(dur!"days"(5)) == 5*24*60);

    assertThrown!AssertError(TimeFrame(dur!"minutes"(61)));

    tf = 1;
    tf *= 5;
    assert(tf == 5);
    assertThrown!AssertError(tf *= -100);

    assert(TimeFrame(5) > TimeFrame(1));
}
