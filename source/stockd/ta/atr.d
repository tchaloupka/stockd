module stockd.ta.atr;

import std.math;
import std.range;
import stockd.defs.bar;

/**
 * Average true range (ATR)
 * 
 * Ref: <a href="http://stockcharts.com/school/doku.php?st=atr&id=chart_school:technical_indicators:average_true_range_a">stockcharts.com</a>
 * 
 * Developed by J. Welles Wilder, the Average True Range (ATR) is an indicator that measures volatility.
 * As with most of his indicators, Wilder designed ATR with commodities and daily prices in mind.
 * Commodities are frequently more volatile than stocks. They were are often subject to gaps and limit moves, 
 * which occur when a commodity opens up or down its maximum allowed move for the session. A volatility formula 
 * based only on the high-low range would fail to capture volatility from gap or limit moves.
 * Wilder created Average True Range to capture this "missing" volatility. It is important to remember that ATR 
 * does not provide an indication of price direction, just volatility.
 */
auto atr(R)(R input, ushort period = 14)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    return ATR!R(input, period);
}

/// dtto
struct ATR(R)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    private ushort period;
    private ushort lPeriod;
    private double prevAtr = 0;
    private double prevClose = 0;
    private ushort idx;
    private double m1, m2, m3;

    R input;
    
    this(R input, ushort period = 14)
    {
        assert(period > 0);

        this.input = input;
        this.period = period;
        this.lPeriod = cast(ushort)(period - 1);
    }
    
    @property bool empty()
    {
        return input.empty;
    }
    
    @property auto front()
    {
        auto bar = input.front;

        m1 = bar.high - bar.low;
        
        if(idx == 0)
        {
            prevAtr = m1;
            idx++;
        }
        else
        {
            m2 = abs(bar.low - prevClose);
            m3 = abs(bar.high - prevClose);
            
            if(m2 > m1) m1 = m2;
            if(m3 > m1) m1 = m3;
            
            if(idx < period)
            {
                prevAtr = (prevAtr * idx + m1) / (idx + 1);
                idx++;
            }
            else
            {
                prevAtr = (prevAtr * lPeriod + m1) / period;
            }
        }
        
        prevClose = bar.close;
        
        return prevAtr;
    }
    
    void popFront()
    {
        input.popFront();
    }
}

unittest
{
    import std.csv;
    import std.stdio;
    import std.datetime;

    writeln(">> ATR tests <<");
    
    struct Layout {double high; double low; double close;}
    
    auto strBars = r"48.7000;47.7900;48.1600
48.7200;48.1400;48.6100
48.9000;48.3900;48.7500
48.8700;48.3700;48.6300
48.8200;48.2400;48.7400
49.0500;48.6350;49.0300
49.2000;48.9400;49.0700
49.3500;48.8600;49.3200
49.9200;49.5000;49.9100
50.1900;49.8700;50.1300
50.1200;49.2000;49.5300
49.6600;48.9000;49.5000
49.8800;49.4300;49.7500
50.1900;49.7250;50.0300
50.3600;49.2600;50.3100
50.5700;50.0900;50.5200
50.6500;50.3000;50.4100
50.4300;49.2100;49.3400
49.6300;48.9800;49.3700
50.3300;49.6100;50.2300
50.2900;49.2000;49.2375
50.1700;49.4300;49.9300
49.3200;48.0800;48.4300
48.5000;47.6400;48.1800
48.3201;41.5500;46.5700
46.8000;44.2833;45.4100
47.8000;47.3100;47.7700
48.3900;47.2000;47.7200
48.6600;47.9000;48.6200
48.7900;47.7301;47.8500";
    
    auto records = csvReader!Layout(strBars,';');
    Bar[] bars;
    foreach(r; records)
    {
        bars ~= Bar(DateTime(2010, 1, 1, 1), r.close, r.high, r.low, r.close);
    }
    
    double[] expected = [0.91000, 0.74500, 0.66667, 0.62500, 0.61600, 0.58250, 0.53643, 0.53063, 0.53833, 0.51650, 0.55409, 0.57125, 0.56192, 0.55500, 0.59393, 0.58579, 0.56895, 0.61545, 0.61792, 0.64235, 0.67433, 0.69277, 0.77543, 0.78147, 1.20923, 1.30262, 1.38029, 1.36670, 1.33622, 1.31648];

    auto range = atr(bars, 14);
    assert(isInputRange!(typeof(range)));
    double[] evaluated = range.array;
    assert(approxEqual(expected, evaluated));
    
    auto wrapped = inputRangeObject(atr(bars, 14));
    evaluated = wrapped.array;
    assert(approxEqual(expected, evaluated));

    writeln(">> ATR tests OK <<");
}

