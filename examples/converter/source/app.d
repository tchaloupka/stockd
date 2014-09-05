import std.stdio;

import stockd.defs;
import stockd.data.marketdata;
import stockd.conv.tfconv;

void main(string[] args)
{
    //TODO: use std.getopt to specify multiplier, source file, output file (if stdin and stdout are not used), and target file format
    auto data = marketData(File("data/EURUSD_M1_201311.csv", "r"), "TEST");

    foreach(b; data)
    {
        writeln(b);
    }

    readln;
}
