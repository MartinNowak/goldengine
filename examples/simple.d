import std.datetime, std.stdio;
import goldengine.constants, goldengine.cgtloader, goldengine.datatypes, goldengine.lexer, goldengine.parser;

int main(string[] args) {
  if (args.length < 3) {
    std.stdio.stderr.writeln("simple grammar.cgt <files>");
    return 1;
  }

  auto tables = loadFromFile(args[1]);
  auto lexer = mkLexer(tables);

  foreach(arg; args[2 .. $]) {
    lexer.input = std.file.readText(arg);

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
