import std.datetime, std.stdio, std.stream;
import goldengine.constants, goldengine.cgtloader, goldengine.datatypes, goldengine.lexer, goldengine.parser;

int main(string[] args) {
  if (args.length < 3) {
    std.stdio.stderr.writeln("simple grammar.cgt <files>");
    return 1;
  }

  auto tabs = loadFromFile(args[1]);

  scope auto parser = new Parser(tabs);
  foreach(arg; args[2 .. $]) {
    parser.setInput(new BufferedFile(arg));

    while (1) {
      auto msg = parser.parse();
      if (msg > Message.Accept) {
        writeln("Error ", msg);
        break;
      }
      if (msg == Message.TokenRead)
        writefln("parse msg:%s state:%s value:%s tok:%s", msg, parser.state,
                 parser.inputStack[$-1].data,
                 parser.tabs.symbols[parser.inputStack[$-1].symbol].name);
      else
        writefln("parse msg:%s state:%s", msg, parser.state);
      if (msg == Message.Accept) {
        // done
        writeln(parser.stack);
        break;
      }
    }
  }
  return 0;
}
