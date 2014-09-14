/**
 * 
 * /home/tomas/workspace/trading/stockd/source/stockd/eval/evaluator.d
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
module stockd.eval.evaluator;

import std.traits;
import std.range;

import pegged.grammar;
import stockd.data;
import stockd.defs;
import stockd.ta;

enum evaluatorGrammar = `
    Eval:
        #filter defs
        FILTERLIST  <  (FILTER (:';' FILTER)+ / FILTER) :';'?
        FILTER      <  WITHPARAMS / SIMPLE
        WITHPARAMS  <  FUNC :"(" (FILTER / SIMPLE / PARAM) (:',' PARAM)? :")"
        SIMPLE      <  SIMPLEABLE (&',' / &';' / !. / :("()"))
        
        #functions with params
        FUNC        <- ATR / SMA / EMA / CCI / BOLLINGER / MACD / MAX / MIN / MEDIAN / STDDEV / STOCHASTIC
        
        #functions with no or default params
        SIMPLEABLE  <- AVG 
            / ATR  / CCI / CURDAYOHL / SMA/ EMA / HEIKENASHI / MACD / MAX / MIN 
            / MEDIAN / STDDEV / STOCHASTIC / TYPICALP / TRUERANGE
        
        #func names
        ATR         <- 'atr'
        AVG         <- 'avg'
        SMA         <- 'sma'
        EMA         <- 'ema'
        CCI         <- 'cci'
        BOLLINGER   <- 'bollinger'
        CURDAYOHL   <- 'curDayOHL'
        HEIKENASHI  <- 'heikenashi'
        MACD        <- 'macd'
        MAX         <- 'max'
        MIN         <- 'min'
        MEDIAN      <- 'median'
        STDDEV      <- 'stddev'
        STOCHASTIC  <- 'stoch'
        TYPICALP    <- 'typical'
        TRUERANGE   <- 'tr'

        #parameter def
        PARAM       <- NUMBER / BOOL
        
        #numbers
        NUMBER      <- FLOAT / UINT / INT
        FLOAT       <~ INT ~'.' ~UINT
        INT         <~ SIGN? UINT
        UINT        <~ [0-9]+
        SIGN        <~ '-' / '+'

        #bool param
        BOOL        <- 'true' / 'false'
    `;

/// insert evaluator grammar parser
mixin(grammar(evaluatorGrammar));

unittest
{
    import std.stdio;

    auto parsedTree = Eval(r"sma(atr(14), 10); ema(1.2); cci(); tr; sma;");
    assert(parsedTree.successful);
    assert(parsedTree.matches == ["sma", "atr", "14", "10", "ema", "1.2", "cci", "tr", "sma"]);

    parsedTree = Eval(r"typical();");
    assert(parsedTree.successful);

    parsedTree = Eval(r"sma");
    assert(parsedTree.successful);

    parsedTree = Eval(r"tr()");
    assert(parsedTree.successful);

    parsedTree = Eval(r"tro(14)");
    assert(!parsedTree.successful);
}

/**
 * Initializes compile time evaluator
 */
auto evaluator(string def, R)(R input)
    if(isInputRange!R && is(ElementType!R == Bar))
{
    enum peggedEval = Eval(def);
    return Evaluator!(R, peggedEval)(input);
}

/// Evaluator to evaluate specified chained filter
struct Evaluator(R, ParseTree def)
    if(isInputRange!R && is(ElementType!R == Bar))
{

    /// create Evaluator implementation
    static auto evaluatorImpl(R, ParseTree def)()
    {
        string params = `
            R _input;
            `;
        
        string constructor = `
            this(R input)
            {
                this._input = input;
            `;
        
        string rangeImpl = `
            void popFront()
            {
                _expr.popFront();
            }

            @property bool empty()
            {
                return _expr.empty;
            }

            @property auto ref front()
            {
                return _expr.front;
            }
            `;

        int filterNum;

        void parseTree(ParseTree tr)
        {
            import std.conv;

            switch(tr.name)
            {
                case "Eval.TYPICALP": //typical price
                    params ~= "TypicalPrice!R _indicator" ~ to!string(filterNum) ~ ";\n            ";
                    constructor ~= "    _indicator" ~ to!string(filterNum++) ~ " = typicalPrice(_input);\n            ";
                    break;
                case "Eval.TRUERANGE": //true range
                    params ~= "TrueRange!R _indicator" ~ to!string(filterNum) ~ ";\n            ";
                    constructor ~= "    _indicator" ~ to!string(filterNum++) ~ " = trueRange(_input);\n            ";
                    break;
                case "Eval.FILTER":
                    //pass next to SIMLE / WITHPARAMS
                    assert(tr.children.length == 1);
                    parseTree(tr.children[0]);
                    break;
                case "Eval.SIMPLEABLE":
                    //pass next to filter type
                    assert(tr.children.length == 1);
                    parseTree(tr.children[0]);
                    break;
                case "Eval.SIMPLE":
                    //pass next to SIMPLEABLE
                    assert(tr.children.length == 1);
                    parseTree(tr.children[0]);
                    break;
                case "Eval.WITHPARAMS":
                    assert(0, "Not implemented yet!");
                    //break;
                default:
                    assert(0, "Unexpected element " ~ tr.name);
            }
        }

        //add all filters
        assert(def.name == "Eval");
        assert(def.children.length == 1);
        assert(def.children[0].name == "Eval.FILTERLIST");
        foreach(f; def.children[0].children)
        {
            assert(f.name == "Eval.FILTER");

            parseTree(f);
        }

        //close constructor
        constructor ~= '}';

        //create combined filter for output
        assert(filterNum > 0);
        if(filterNum == 1)
        {
            params ~= "alias _indicator0 _expr;";
        }
        else assert(0, "Not implemented yet!");

        return params ~ '\n' ~ constructor ~ '\n' ~ rangeImpl;
    }

    //pragma(msg, evaluatorImpl!(R, def));

    mixin(evaluatorImpl!(R, def));
}

/// Typical price test
unittest
{
    import std.stdio;
    import std.math;
    import stockd.data;
    import stockd.defs;

    import std.traits;

    auto data = marketData([
            bar!"20000101;2;4;1;3;100",
            bar!"20000101;10;20;5;15;100",
            bar!"20000101;0.1;1;0.1;0.6;100"
    ]);
    
    enum expected = [2.666667, 13.33333, 0.566666];
    auto testEval = evaluator!(r"typical()", typeof(data))(data);
    assert(approxEqual(expected, testEval.array));
}

/// True range test
unittest
{
    import std.stdio;
    import std.csv;
    import std.datetime;
    import std.math;
    import stockd.data;
    import stockd.defs;

    struct Layout {double high; double low; double close;}
    
    // bars str
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
    
    double[] expected = [
        0.91000, 0.58000, 0.51000, 0.50000, 0.58000, 0.41500, 0.26000, 0.49000, 
        0.60000, 0.32000, 0.93000, 0.76000, 0.45000, 0.46500, 1.10000, 0.48000, 
        0.35000, 1.22000, 0.65000, 0.96000, 1.09000, 0.93250, 1.85000, 0.86000, 
        6.77010, 2.51670, 2.39000, 1.19000, 0.94000, 1.05990];

    auto testEval = evaluator!(r"tr", typeof(bars))(bars);
    assert(approxEqual(expected, testEval.array));
}
