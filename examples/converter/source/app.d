import std.stdio;
import std.getopt;
import std.file;
import std.exception : enforce;
import std.array;
import std.datetime;
import std.path;
import std.string : indexOf;

import stockd.defs;
import stockd.data;
import stockd.conv.tfconv;

int main(string[] args)
{
    StopWatch sw;
    sw.start();

    string inputFilePath;
    string outputFilePath;
    uint multiply = 1;
    FileFormat ff = FileFormat.ninjaTrader;

    getopt(
        args,
        "input|i", &inputFilePath,
        "output|o", &outputFilePath,
        "multiply|m", &multiply,
        "format|f", &ff);

    debug
    {
        if(inputFilePath.empty) inputFilePath = "data/EURUSD_M1_201311.csv";
    }

    enforce(ff != FileFormat.guess, "Invalid option for output format");
    enforce(inputFilePath.empty || (inputFilePath.exists && inputFilePath.isFile), "Invalid input file: " ~ inputFilePath);

    auto input = inputFilePath.empty? stdin : File(inputFilePath, "r");
    auto output = outputFilePath.empty? stdout : File(outputFilePath, "w");

    auto symbol = "stdin";
    if(!inputFilePath.empty)
    {
        import std.algorithm : min;

        auto name = baseName(inputFilePath);
        auto idx = min(indexOf(name, '_'), indexOf(name, '.'), name.length);
        symbol = name[0..idx];
    }

    auto inputRange = marketData(input, Symbol(symbol));
    auto data = inputRange.tfConv(multiply);

    writefln("Input: %s.%s", inputRange.symbol, inputRange.timeFrame);
    writefln("Output: %s.%s", data.symbol, data.timeFrame);

    string formatStr;

    final switch(ff)
    {
        case FileFormat.guess:
        case FileFormat.ninjaTrader:
            formatStr = "%n";
            break;
        case FileFormat.tradeStation:
            formatStr = "%t";
            break;
    }

    foreach(b; data)
    {
        output.writefln(formatStr, b);
    }

    sw.stop();

    writefln("Duration: %s ms", sw.peek.msecs);

    return 0;
}
