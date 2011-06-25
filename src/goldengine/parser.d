module goldengine.parser;

import std.algorithm, std.exception, std.range, std.variant;
import goldengine.constants, goldengine.cgtloader;

struct Token { Symbol symbol; Variant data; }

class Parser {
  this(CGTable table) {
    //    enforce(table.params.caseSens, "case insensitive grammars unsupported");
    this.table = table;
  }

  void parse() {
    size_t commentLevel;
    Token[] inputStack;
    auto start = Token(table.symbols[table.params.startSymidx]);
    inputStack ~= start;
  }

  Token getNextToken() {
    Token tok;

    if (data.empty)
      tok.symbol.kind = SymbolKind.EndOfFile;
    else {
      int state = table.initDFAState;
      bool done;
      size_t len = 0;

      int accstate = -1;
      size_t acclen;

      while (!done) {
        if (table.dfastates[state].acc) {
          accstate = state;
          acclen = len;
        }

        int nextstate = -1;
        foreach(ref edge; table.dfastates[state].edges) {
          //          assert(len < data.length, std.conv.to!string(len) ~ std.conv.to!string(data.front));
          if (canFind(table.charsets[edge.charsetidx], len == data.length ? dchar.init : data[len])) {
            nextstate = edge.targetstate;
            break;
          }
        }

        if (nextstate != -1) {
          state = nextstate;
          ++len;
        } else {
          if (accstate != -1) {
            tok.symbol = table.symbols[table.dfastates[accstate].accsymidx];
            tok.data = data[0 .. acclen];
            data = data[acclen .. $];
          } else {
            tok.symbol.kind = SymbolKind.Error;
            tok.data = data[0 .. len];
            data = data[1 .. $]; // pop one char to possibly recover
          }
          done = true;
        }
      }
    }
    return tok;
  }

  CGTable table;
  string data;
}

