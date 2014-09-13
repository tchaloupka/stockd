module stockd.defs.timeFrame;

import stockd.defs.common;

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
    import core.time;

    mixin property!(uint, "totalMinutes");

    @nogc @safe @property pure nothrow
    {
        /// Gets TF total hours
        auto totalHours() const
        {
            return _totalMinutes / 60;
        }

        /// Gets TF total days
        auto totalDays() const
        {
            return _totalMinutes / (60*24);
        }

        /// Gets TF total weeks
        auto totalWeeks() const
        {
            return _totalMinutes / (60*24*7);
        }

        auto origin() const
        {
            if(_totalMinutes >= 60 * 24 * 7) return Origin.week;
            else if(_totalMinutes >= 60 * 24) return Origin.day;
            else if(_totalMinutes >= 60 ) return Origin.hour;
            return Origin.minute;
        }
    }

    @nogc @safe pure nothrow const invariant()
    {
        if(_totalMinutes >= 60 * 24 * 7) assert(_totalMinutes % (60 * 24 * 7) == 0);  //Wx
        else if(_totalMinutes >= 60 * 24) assert(_totalMinutes % (60 * 24) == 0);   // Dx
        else if(_totalMinutes >= 60 ) assert(_totalMinutes % 60 == 0);  // Hx
    }

    @nogc @safe pure nothrow
    {
        this(uint minutes)
        {
            this._totalMinutes = minutes;
        }

        this(Duration duration)
        {
            this._totalMinutes = cast(uint)(duration.total!"minutes");
        }
    }

    pure toString() const
    {
        import std.string;

        if(_totalMinutes < 60) return format("m%s", _totalMinutes);
        if(_totalMinutes < 60 * 24) return format("h%s", _totalMinutes / 60);
        if(_totalMinutes < 60 * 24 * 7) return format("d%s", _totalMinutes / (60*24));
        return format("w%s", _totalMinutes / (60*24*7));
    }

    @nogc @safe pure nothrow
    {
        TimeFrame opAssign(T)(auto ref in T rhs)
            if(is(T:uint) || is(Unqual!T == Duration) || is(Unqual!T == TimeFrame))
        {
            static if(is(Unqual!T == Duration))
            {
                this._totalMinutes = cast(uint)(rhs.total!"minutes");
            }
            else static if(is(Unqual!T == TimeFrame))
            {
                this._totalMinutes = rhs._totalMinutes;
            }
            else static if(is(T:uint))
            {
                this._totalMinutes = rhs;
            }

            return this;
        }

        TimeFrame opOpAssign(string op)(in int mul)
            if(op == "*")
        {
            this._totalMinutes *= mul;
            return this;
        }

        bool opEquals(T)(auto ref in T rhs) const
            if(is(T : int) || is(Unqual!T == Duration) || is(Unqual!T == TimeFrame))
        {
            static if(is(Unqual!T == Duration)) return this._totalMinutes == rhs.total!"minutes";
            else static if(is(Unqual!T == TimeFrame)) return this._totalMinutes == rhs._totalMinutes;
            else static if(is(Unqual!T:int)) return this._totalMinutes == rhs;

            assert(0, "Not implemented type");
        }

        int opCmp(T)(auto ref in T other) const
            if(is(T:int) || is(Unqual!T == TimeFrame) || is(Unqual!T == Duration))
        {
            int min;
            static if(is(T == TimeFrame))
            {
                min = other._totalMinutes;
            }
            else static if(is(T : Duration))
            {
                min = cast(int)other.total!"minutes";
            }
            else static if(is(T:int))
            {
                min = other;
            }
            else assert(0, "Not implemented type");

            if(this._totalMinutes < min) return -1;
            if(this._totalMinutes == min) return 0;
            return 1;
        }
    }

    /// implicit conversion to uint
    alias totalMinutes this;
}

unittest
{
    import core.exception;
    import std.exception;
    import core.time;
    
    assert(TimeFrame(5) == 5);
    assert(TimeFrame(60) == 60);
    assertThrown!AssertError(TimeFrame(61));
    
    assert(TimeFrame(5) == 5);
    assert(TimeFrame(60) == 60);
    assert(TimeFrame(60*24) == timeFrame!"day"(1));
    assert(TimeFrame(60*48) == timeFrame!"day"(2));
    assert(TimeFrame(60*24*7) == timeFrame!"week"(1));
    
    TimeFrame tf = 1;
    assert(tf == 1);
    assert((tf = timeFrame!"m"(5)) == 5);
    
    assert(tf == dur!"minutes"(5));
    assert((tf = timeFrame!"h"(5)) == dur!"hours"(5));
    
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

/**
 * Helper function to create TimeFrame struct.
 */
@nogc @safe pure nothrow auto timeFrame(string origin = "m")(uint value)
    if(origin == "m" || origin == "h" || origin == "d" || origin == "w" ||
       origin == "M" || origin == "H" || origin == "D" || origin == "W" ||
       origin == "minute" || origin == "hour" || origin == "day" || origin == "week")
{
    final switch(origin)
    {
        case "m", "M", "minute": return TimeFrame(value);
        case "h", "H", "hour": return TimeFrame(value * 60);
        case "d", "D", "day": return TimeFrame(value * 60 * 24);
        case "w", "W", "week": return TimeFrame(value * 60 * 24 * 7);
    }
}

unittest
{
    assert(timeFrame!"m"(10) == 10);
    assert(timeFrame!"H"(5) == 5 * 60);
    assert(timeFrame!"day"(2) == 2 * 60 * 24);
    assert(timeFrame!"week"(2) == 2 * 60 * 24 * 7);
    assert(timeFrame!"m"(10) == timeFrame(10));
}

import std.range;
import stockd.defs.bar;

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
    import stockd.data;

    auto data = marketData(
        r"20110715 205500;1.41540;1.41545;1.41491;1.41498;33450
        20110715 210000;1.41500;1.41561;1.41473;1.41532;73360"
        ).array;
    assert(guessTimeFrame(data) == 5);
    
    data = marketData(
        r"20110715 205500;1.41540;1.41545;1.41491;1.41498;33450
        20110715 205500;1.41500;1.41561;1.41473;1.41532;73360"
        ).array;
    assert(guessTimeFrame(data) == TimeFrame.init);
    
    data = marketData(
        r"20110715 205500;1.41540;1.41545;1.41491;1.41498;33450"
        ).array;
    assert(guessTimeFrame(data) == TimeFrame.init);
    
    data = marketData(
        r"20110715 205500;1.41540;1.41545;1.41491;1.41498;33450
        20110715 215500;1.41500;1.41561;1.41473;1.41532;73360"
        ).array;
    assert(guessTimeFrame(data) == 60);
}
