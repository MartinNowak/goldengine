module goldengine.lexer;

import std.algorithm, std.range, std.utf;
import goldengine.cgtloader, goldengine.datatypes, goldengine.constants;

class Lexer {
  this(CGTables tabs) {
    this.tabs = tabs;
  }

  void setInput(string s) {
    this._input = s;
  }

  Token getNextToken() {
    Token tok;

    if (_input.empty)
      tok.symbol = SpecialSymbol.EndOfFile;
    else {
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

        int nextstate = -1;
        dchar ch = len == _input.length ? dchar.init : _input[len]; // dchar.init is illegal and serves as EOF
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
          if (accstate != -1) {
            tok.symbol = tabs.dfatable[accstate].acceptSymbol;
            tok.data = _input[0 .. acclen];
            _input = _input[acclen .. $];
          } else {
            tok.symbol = SpecialSymbol.Error;
            tok.data = _input[0 .. len];
            _input.popFront; // pop one char to possibly recover
          }
          done = true;
        }
      }
    }
    return tok;
  }

  CGTables tabs;
  string _input;
}
