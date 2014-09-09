import std.stdio;
import std.getopt;
import std.file;
import std.exception;
import std.array;

import stockd.defs;
import stockd.data.marketdata;
import stockd.conv.tfconv;

int main(string[] args)
{
    string inputFileName;
    string outputFileName;
    uint multiply = 1;
    FileFormat ff = FileFormat.ninjaTrader;

    getopt(
        args,
        "input|i", &inputFileName,
        "output|o", &outputFileName,
        "multiply|m", &multiply,
        "format|f", &ff);

    debug
    {
        if(inputFileName.empty) inputFileName = "data/EURUSD_M1_201311.csv";
    }

    enforce(ff != FileFormat.guess, "Invalid option for output format");
    enforce(inputFileName.empty || (inputFileName.exists && inputFileName.isFile), "Invalid input file: " ~ inputFileName);

    auto input = inputFileName.empty? stdin : File(inputFileName, "r");
    auto output = outputFileName.empty? stdout : File(outputFileName, "w");

    auto data = marketData(input).tfConv(multiply);

    foreach(bar; data)
    {
        //TODO: implement output range to write directly to file and avoid allocations in bar.toString
        output.writeln(bar.toString(ff));
    }

    return 0;
}
