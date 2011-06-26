import std.datetime, std.stdio;
import goldengine.constants, goldengine.cgtloader, goldengine.datatypes, goldengine.lexer, goldengine.parser;

int main(string[] args) {
  if (args.length < 3) {
    std.stdio.stderr.writeln("simple grammar.cgt <files>");
    return 1;
  }

  auto tables = loadFromFile(args[1]);

  auto parser = mkParser(tables);
  foreach(arg; args[2 .. $]) {
    parser.reset();
    parser.lexer.input = std.file.readText(arg);

    auto msg = parser.parse();
    while (msg != Message.Accept) {
      if (msg > Message.Accept) {
        writeln("Error ", msg);
        break;
      }
      if (msg == Message.TokenRead)
        writefln("parse msg:%s state:%s value:%s tok:%s", msg, parser.state,
                 parser.inputStack[$-1].data,
                 parser.symbols[parser.inputStack[$-1].symbol].name);
      else
        writefln("parse msg:%s state:%s", msg, parser.state);
      msg = parser.parse();
    }
  }
  return 0;
}
