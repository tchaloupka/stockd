/**
 * 
 * /home/tomas/workspace/trading/stockd/source/stockd/data/nrepeat.d
 * 
 * Author:
 * Tomáš Chaloupka <chalucha@gmail.com>
 * 
 * Copyright (c) 2014 ${CopyrightHolder}
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
module stockd.data.nrepeat;

import std.range;
import stockd.defs;
import stockd.data.marketdata;

/**
 * Repeats each element of input range n-times.
 * Must be class because it is targeted to be reused as input for other ranges and this wont work with structs.
 */
class NRepeat(R)
    if (isInputRange!R)
{
    private R _input;
    private ElementType!R _current;
    private uint _times;
    private uint _n;

    this(R input, uint times)
    {
        assert(times > 0);

        _input = input;
        _current = input.front;
        _times = times;
    }

    @property auto ref front()
    {
        return _current;
    }

    @property bool empty()
    {
        return _input.empty;
    }

    void popFront()
    {
        if(++_n == _times)
        {
            _input.popFront();
            if(!empty) _current = _input.front;
            _n = 0;
        }
    }
}

auto nRepeat(R)(R input, uint times)
    if (isInputRange!R)
{
    return new NRepeat!R(input, times);
}

unittest
{
    int[] a = [1,2,3,4,5];
    assert(equal(nRepeat(a, 1), [1,2,3,4,5][]));
    assert(equal(nRepeat(a, 2), [1,1,2,2,3,3,4,4,5,5][]));
    assert(equal(nRepeat(a, 3), [1,1,1,2,2,2,3,3,3,4,4,4,5,5,5][]));

    string barsText = r"20110715 205500;1.4154;1.41545;1.41491;1.41498;33450
        20110715 205600;1.415;1.4152;1.41481;1.41481;11360
        20110715 205700;1.41486;1.41522;1.41477;1.41486;31010
        20110715 205800;1.41488;1.41506;1.41473;1.41502;15170
        20110715 205900;1.41489;1.41561;1.41486;1.41561;15280
        20110715 210000;1.41549;1.41549;1.41532;1.41532;540";

    Bar[] expected = [
        bar!"20110715 205500;1.4154;1.41545;1.41491;1.41498;33450",
        bar!"20110715 205500;1.4154;1.41545;1.41491;1.41498;33450",
        bar!"20110715 205600;1.415;1.4152;1.41481;1.41481;11360",
        bar!"20110715 205600;1.415;1.4152;1.41481;1.41481;11360",
        bar!"20110715 205700;1.41486;1.41522;1.41477;1.41486;31010",
        bar!"20110715 205700;1.41486;1.41522;1.41477;1.41486;31010",
        bar!"20110715 205800;1.41488;1.41506;1.41473;1.41502;15170",
        bar!"20110715 205800;1.41488;1.41506;1.41473;1.41502;15170",
        bar!"20110715 205900;1.41489;1.41561;1.41486;1.41561;15280",
        bar!"20110715 205900;1.41489;1.41561;1.41486;1.41561;15280",
        bar!"20110715 210000;1.41549;1.41549;1.41532;1.41532;540",
        bar!"20110715 210000;1.41549;1.41549;1.41532;1.41532;540"
    ];

    auto range = nRepeat(marketData(barsText), 2);
    assert(isInputRange!(typeof(range)));
    assert(is(ElementType!(typeof(range)) == Bar));
    auto data = range.array;
    assert(data == expected);

    range = nRepeat(marketData(barsText), 2);
    for(int i=0; !range.empty; i++)
    {
        assert(range.front == expected[i*2]);
        range.popFront();
        range.popFront();
    }
}
