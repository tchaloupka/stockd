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

/**
 * Repeats each element of input range n-times
 */
struct NRepeat(R)
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

    @property auto ref front() const
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
    return NRepeat!R(input, times);
}

unittest
{
    int[] a = [1,2,3,4,5];
    assert(equal(nRepeat(a, 2), [1,1,2,2,3,3,4,4,5,5][]));
    assert(equal(nRepeat(a, 3), [1,1,1,2,2,2,3,3,3,4,4,4,5,5,5][]));
}
