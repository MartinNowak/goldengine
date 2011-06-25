import std.datetime, std.stdio;
import goldengine.constants, goldengine.cgtloader, goldengine.datatypes, goldengine.lexer, goldengine.parser;

int main(string[] args) {
  if (args.length < 3) {
    std.stdio.stderr.writeln("simple grammar.cgt <files>");
    return 1;
  }

  auto tables = loadFromFile(args[1]);

  foreach(arg; args[2 .. $]) {
    auto testdata = std.file.readText(arg);
    auto lexer = Lexer(testdata, tables.dfatable, tables.charsets, tables.symbols);

    size_t count;
    auto tok = lexer.getNextToken();
    while (tok.symbol != SpecialSymbol.EndOfFile) {
      if (tok.symbol == SpecialSymbol.Error) {
        writeln("Error ", tok.data);
        break;
      }
      writeln(tables.symbols[tok.symbol].name, " ", tok.data);
      ++count;
      tok = lexer.getNextToken();
    }
    writefln("file:%s tokencount:%s", arg, count);
  }
  return 0;
}
