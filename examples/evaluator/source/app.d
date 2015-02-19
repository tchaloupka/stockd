import std.getopt;
import std.file;
import std.stdio;
import std.range;
import std.datetime;
import std.exception : enforce;

import stockd.ta;
import stockd.data;

int main(string[] args)
{
    StopWatch sw;
    sw.start();

    string inputFilePath;
    string outputFilePath;

    getopt(
        args,
        "input|i", &inputFilePath,
        "output|o", &outputFilePath
        );

    debug
    {
        if(inputFilePath.empty) inputFilePath = "../../data/EURUSD.M1.txt";
    }

    enforce(inputFilePath.empty || (inputFilePath.exists && inputFilePath.isFile), "Invalid input file: " ~ inputFilePath);

    auto input = File(inputFilePath, "r");
    auto output = outputFilePath.empty? stdout : File(outputFilePath, "w");

    auto bars = nRepeat(marketData(input), 4);
    auto tpRange = bars.typicalPrice();
    auto macd = bars.map!"a.close".macd();
    auto cdohl = bars.curDayOHL(TimeOfDay(8, 0, 0));

    output.writeln("time;open;high;low;close;vol;tp;macd_hist;cd_open;cd_high;cd_low");
    foreach(bar, tp, ma, cd; lockstep(bars, tpRange, macd, cdohl))
    {
        output.writefln("%n;%.5f;%g;%.5f;%.5f;%.5f;", bar, tp, ma[2], cd[0], cd[1], cd[2]);
    }

    input.close();
    output.close();

    sw.stop();
    writefln("Duration: %s ms", sw.peek.msecs);

    return 0;
}
