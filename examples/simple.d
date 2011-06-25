import std.stdio;
import goldengine.constants, goldengine.cgtloader, goldengine.parser;

int main(string[] args) {
  if (args.length < 3) {
    std.stdio.stderr.writeln("simple grammar.cgt <files>");
    return 1;
  }

  auto table = loadFromFile(args[1]);
  auto parser = new Parser(table);

  foreach(arg; args[2 .. $]) {
    auto testdata = std.file.readText(arg);
    parser.data = testdata;
    size_t count;
    Token tok;
    do {
      tok = parser.getNextToken();
      if (tok.symbol.kind == SymbolKind.Error) {
        writeln("Error ", tok.data);
        break;
      }
      //      writeln(tok.symbol.name, " ", tok.data);
      ++count;
    } while (tok.symbol.kind != SymbolKind.EndOfFile);
    writeln(arg, "tokencount:", ++count);
  }
  return 0;
}
