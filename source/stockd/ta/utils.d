module stockd.ta.utils;

import std.datetime;
import std.stdio;

/**
 * Check if new time is after the start time of the next trading session.
 * Usable for overlay indicators which change values with the new sessions (CurrentDayOHL, PivotPoints, ...)
 * 
 * Params:
 *      current - current DateTime - will be changed to session start time
 *      newTime - DateTime of the new bar
 *      sessionStart - TimeOfDay the trading session starts
 */
static bool isNextSession(ref DateTime current, DateTime newTime, TimeOfDay sessionStart)
{
    if(current == DateTime.min() || (newTime - current).total!"minutes" >= 1440) //first bar or next session
    {
        current = newTime;
        if(current.hour < sessionStart.hour || ((current.hour == sessionStart.hour) && (current.minute < sessionStart.minute)))
        {
            //move back one day
            current -= dur!"days"(1);
        }
        current.hour = sessionStart.hour;
        current.minute = sessionStart.minute;
        
        return true;
    }
    
    return false;
}

unittest
{
    auto sessionStart = TimeOfDay(9, 0, 0);
    DateTime time;
    assert(isNextSession(time, DateTime(2010, 10, 1, 8, 0, 0), sessionStart) == true); //first session
    assert(time == DateTime(2010, 9, 30, 9, 0, 0));
    assert(isNextSession(time, DateTime(2010, 10, 1, 8, 30, 0), sessionStart) == false); //next bar in session
    assert(time == DateTime(2010, 9, 30, 9, 0, 0));
    assert(isNextSession(time, DateTime(2010, 10, 1, 9, 0, 0), sessionStart) == true); //next session with exact time
    assert(time == DateTime(2010, 10, 1, 9, 0, 0));
    assert(isNextSession(time, DateTime(2010, 10, 1, 12, 30, 0), sessionStart) == false); //next bar in session
    assert(time == DateTime(2010, 10, 1, 9, 0, 0));
    assert(isNextSession(time, DateTime(2010, 10, 2, 1, 0, 0), sessionStart) == false); //next bar in session
    assert(time == DateTime(2010, 10, 1, 9, 0, 0));
    assert(isNextSession(time, DateTime(2010, 10, 3, 1, 0, 0), sessionStart) == true); //next session with delay
    assert(time == DateTime(2010, 10, 2, 9, 0, 0));
}