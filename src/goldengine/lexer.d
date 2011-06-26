module goldengine.lexer;

import std.algorithm, std.exception, std.range, std.stream, std.utf;
import goldengine.cgtloader, goldengine.datatypes, goldengine.constants;

class Lexer {
  this(CGTables tabs) {
    this.tabs = tabs;
  }

  void setInput(InputStream inp) {
    this._input = inp;
  }

  Token getNextToken() {
    Token tok;

    if (curline.empty) {
      if (_input.eof)
        tok.symbol = SpecialSymbol.EndOfFile;
      else {
        // TODO: need to copy string for multiline tokens (e.g. comments)
        curline = getln();
        tok.symbol = SpecialSymbol.WhiteSpace;
      }
    } else {
      DFAStateRef state = tabs.dfatable.initState;
      bool done;
      size_t len = 0;

      DFAStateRef accstate = -1;
      size_t acclen;

      while (!done) {
        if (tabs.dfatable[state].isAccepting) {
          accstate = state;
          acclen = len;
        }

        if (len == curline.length)
          goto EOL;
        DFAStateRef nextstate = -1;
        dchar ch = curline[len .. $].front;
        foreach(ref edge; tabs.dfatable[state].edges) {
          auto chs = assumeSorted(tabs.charsets[edge.charset]);
          if (chs.contains(ch)) {
            nextstate = edge.targetState;
            break;
          }
        }

        if (nextstate != -1) {
          state = nextstate;
          len += std.utf.codeLength!char(ch);
        } else {
EOL:
          if (accstate != -1) {
            tok.symbol = tabs.dfatable[accstate].acceptSymbol;
            tok.data = curline[0 .. acclen];
            curline = curline[acclen .. $];
          } else {
            tok.symbol = SpecialSymbol.Error;
            tok.data = curline[0 .. len];
            curline.popFront; // pop one char to possibly recover
          }
          done = true;
        }
      }
    }
    return tok;
  }

  string getln() {
    assert(!_input.eof);
    union Prefix {
      char[9] data;
      align(1) struct { uint fileno; uint lineno; char delim; };
    }
    static assert(Prefix.sizeof == 9);
    Prefix prefix;
    prefix.fileno = fileno;
    prefix.lineno = lineno;
    prefix.delim = 0;

    char[] nline;
    do {
      ++lineno;
      nline = _input.readLine(readbuf);
    } while (nline.empty && !_input.eof);
    readbuf = nline;
    string annline = cast(string)(prefix.data ~ nline ~ '\0');
    assert(!std.exception.pointsTo(readbuf, annline));
    return annline[prefix.sizeof .. $-1];
  }

  CGTables tabs;
  InputStream _input;
  string curline;
  char[] readbuf;
  uint fileno, lineno;
}
