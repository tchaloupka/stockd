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
                    params ~= "TypicalPrice!R _filter" ~ to!string(filterNum) ~ ";\n            ";
                    constructor ~= "    _filter" ~ to!string(filterNum++) ~ " = typicalPrice(_input);\n            ";
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
            params ~= "alias _filter0 _expr;";
        }
        else assert(0, "Not implemented yet!");

        return params ~ '\n' ~ constructor ~ '\n' ~ rangeImpl;
    }

    pragma(msg, evaluatorImpl!(R, def));

    mixin(evaluatorImpl!(R, def));
}

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
