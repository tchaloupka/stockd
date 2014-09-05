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
    import std.traits;

    private uint _minutes;

    /// Gets TF total minutes
    pure nothrow @property auto totalMinutes() @safe @nogc const
    {
        return _minutes;
    }

    /// Gets TF total hours
    pure nothrow @property auto totalHours() @safe @nogc const
    {
        return _minutes / 60;
    }

    /// Gets TF total days
    pure nothrow @property auto totalDays() @safe @nogc const
    {
        return _minutes / (60*24);
    }

    /// Gets TF total weeks
    pure nothrow @property auto totalWeeks() @safe @nogc const
    {
        return _minutes / (60*24*7);
    }

    pure nothrow @property auto origin() @safe @nogc const
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

    pure private static uint parse(in string text) @safe
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
                assert(0, "Invaild format of TimeFrame: " ~ text);
        }
    }

    pure TimeFrame opAssign(in string text) @safe
    {
        this._minutes = parse(text);
        return this;
    }

    pure TimeFrame opAssign(uint minutes) @safe @nogc nothrow
    {
        this._minutes = minutes;
        return this;
    }

    pure TimeFrame opAssign(Duration duration) @safe @nogc nothrow
    {
        this._minutes = cast(uint)(duration.total!"minutes");
        return this;
    }

    pure TimeFrame opOpAssign(string op)(in int mul) @safe @nogc nothrow
        if(op == "*")
    {
        this._minutes *= mul;
        return this;
    }

    pure bool opEquals(in string text) @safe const
    {
        return this._minutes == parse(text);
    }
    pure bool opEquals(int minutes) @safe @nogc const nothrow
    {
        return this._minutes == minutes;
    }

    pure bool opEquals(Duration duration) @safe @nogc const nothrow
    {
        return this._minutes == duration.total!"minutes";
    }

    pure bool opEquals(TimeFrame tf) @safe @nogc const nothrow
    {
        return this._minutes == tf._minutes;
    }

    pure int opCmp(T)(auto ref in T other) @safe const
        if(is(T:int) || is(Unqual!T == TimeFrame) || is(Unqual!T == Duration) || is(T:string))
    {
        int min;
        static if(is(T:int))
        {
            min = other;
        }
        else static if(is(T == TimeFrame))
        {
            min = other._minutes;
        }
        else static if(is(T : Duration))
        {
            min = cast(int)other.total!"minutes";
        }
        else static if(is(T:string)) min = parse(other)._minutes;
        else assert(0, "Unhandled type");

        if(this._minutes < min) return -1;
        if(this._minutes == min) return 0;
        return 1;
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
