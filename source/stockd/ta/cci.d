module stockd.ta.cci;

import std.math;
import std.stdio;
import std.range;
import stockd.defs.bar;
import stockd.ta.templates : Sma;

/**
 * Commodity Channel Index (CCI)
 * 
 * Ref: <a href="http://stockcharts.com/school/doku.php?st=cci&id=chart_school:technical_indicators:commodity_channel_in">stockcharts.com</a>
 * 
 * Introduction:
 * Developed by Donald Lambert and featured in Commodities magazine in 1980, the Commodity Channel Index (CCI) is a versatile indicator 
 * that can be used to identify a new trend or warn of extreme conditions. Lambert originally developed CCI to identify cyclical turns in 
 * commodities, but the indicator can successfully applied to indices, ETFs, stocks and other securities. 
 * In general, CCI measures the current price level relative to an average price level over a given period of time. 
 * CCI is relatively high when prices are far above their average. CCI is relatively low when prices are far below their average. 
 * In this manner, CCI can be used to identify overbought and oversold levels.
 * 
 * Calculation:
 * The example below is based on a 20-period Commodity Channel Index (CCI) calculation. The number of CCI periods is also used for the 
 * calculations of the simple moving average and Mean Deviation.
 * 
 * 
 * CCI = (Typical Price  -  20-period SMA of TP) / (.015 x Mean Deviation)
 * Typical Price (TP) = (High + Low + Close)/3
 * Constant = .015
 * 
 * There are four steps to calculating the Mean Deviation. First, subtract 
 * the most recent 20-period average of the typical price from each period's 
 * typical price. Second, take the absolute values of these numbers. Third, 
 * sum the absolute values. Fourth, divide by the total number of periods (20).
 */
auto cci(R)(R input, ushort period = 14)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    return CCI!R(input, period);
}

/// dtto
struct CCI(R)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    mixin Sma sma;
    private R _input;

    this(R input, ushort period = 14)
    {
        sma.initialize(period);
        this._input = input;
    }

    @property bool empty()
    {
        return _input.empty;
    }
    
    @property auto front()
    {
        auto value = _input.front;

        double typical = (value.high + value.low + value.close)/3;
        double avg = sma.eval(typical);
        
        double mean = 0;
        int len = _isFull ? _period : _idx;
        for (int i = len - 1; i >= 0; i--) { mean += abs(_buffer[i] - avg); }
        mean = mean / len;
        
        return (typical - avg) / (mean == 0 ? 1 : (0.015 * mean));
    }

    void popFront()
    {
        _input.popFront();
    }
}

unittest
{
    import std.csv;
    import std.stdio;
    import std.datetime;

    writeln(">> CCI tests <<");
    
    struct Layout {double open; double high; double low; double close;}
    
    auto strBars = r"23.94290;24.20130;23.85340;23.89320
23.85340;24.07210;23.72420;23.95280
23.94290;24.04230;23.64470;23.67450
23.73420;23.87330;23.36640;23.78390
23.59500;23.67450;23.45590;23.49560
23.45590;23.58510;23.17760;23.32170
23.52550;23.80370;23.39620;23.75400
23.73420;23.80360;23.56520;23.79380
24.09200;24.30070;24.05220;24.14170
23.95280;24.15160;23.77390;23.81370
23.92300;24.05220;23.59500;23.78390
24.04230;24.06220;23.84350;23.86340
23.83360;23.88330;23.64470;23.70440
24.05220;25.13560;23.94290;24.95670
24.88710;25.19520;24.73800;24.87710
24.94670;25.06600;24.76780;24.96160
24.90700;25.21510;24.89700;25.17530
25.24490;25.37410;24.92680;25.06600
25.12560;25.36420;24.95670;25.27470
25.26480;25.26480;24.92680;24.99640
24.73800;24.81750;24.21120;24.45970
24.36030;24.43980;24.21120;24.28080
24.48950;24.64850;24.42990;24.62370
24.69820;24.83740;24.43980;24.58150
24.64850;24.74790;24.20130;24.52680
24.47960;24.50940;24.25100;24.35040
24.45970;24.67840;24.21120;24.34040
24.61870;24.66840;24.15160;24.23110
23.81370;23.84350;23.63480;23.76400
23.91310;24.30070;23.76400;24.20130";

    auto records = csvReader!Layout(strBars,';');
    Bar[] bars;
    foreach(r; records)
    {
        bars ~= Bar(DateTime(2010, 1, 1, 1), r.open, r.high, r.low, r.close);
    }

    double[] expected = [0.00000, -66.66667, -100.00000, -101.00872, -115.38834, -126.05605, -20.49717, 7.39273, 148.20310, 52.05630, 14.03749, 55.03407, -17.10455, 259.92227, 243.90733, 182.08210, 166.50918, 142.16963, 131.64291, 102.31496, 30.73599, 6.55159, 33.29641, 34.95138, 13.84012, -10.74781, -11.58211, -29.34718, -129.35566, -73.06960];

    auto range = cci(bars, 20);
    assert(isInputRange!(typeof(range)));
    double[] evaluated = range.array;
    assert(approxEqual(expected, evaluated));
    
    auto wrapped = inputRangeObject(cci(bars, 20));
    evaluated = wrapped.array;
    assert(approxEqual(expected, evaluated));

    writeln(">> CCI tests OK <<");
}