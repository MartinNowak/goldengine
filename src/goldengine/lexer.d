module goldengine.lexer;

import std.algorithm, std.range, std.utf;
import goldengine.datatypes, goldengine.constants;

struct Lexer {
  Token getNextToken() {
    Token tok;

    if (input.empty)
      tok.symbol = SpecialSymbol.EndOfFile;
    else {
      DFAStateRef state = states.initState;
      bool done;
      size_t len = 0;

      DFAStateRef accstate = -1;
      size_t acclen;

      while (!done) {
        if (states[state].isAccepting) {
          accstate = state;
          acclen = len;
        }

        int nextstate = -1;
        dchar ch = len == input.length ? dchar.init : input[len]; // dchar.init is illegal and serves as EOF
        foreach(ref edge; states[state].edges) {
          //          assert(isSorted(charsets[edge.charset]));
          auto chs = assumeSorted(charsets[edge.charset]);
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
            tok.symbol = states[accstate].acceptSymbol;
            tok.data = input[0 .. acclen]; // need utf slicing
            input.popFrontN(acclen);
          } else {
            tok.symbol = SpecialSymbol.Error;
            tok.data = input[0 .. len];
            input.popFront; // pop one char to possibly recover
          }
          done = true;
        }
      }
    }
    return tok;
  }

  string input;
  DFAStateTable states;
  CharSetTable charsets;
  SymbolTable symbols;
}
