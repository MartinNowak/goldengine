module goldengine.parser;

import std.algorithm, std.exception, std.range, std.stream, std.typecons;
import goldengine.constants, goldengine.cgtloader, goldengine.datatypes, goldengine.lexer;

class Parser : Lexer {
  enum TrimReduction = true;

  this(CGTables tabs) {
    super(tabs);
  }

  override void setInput(InputStream inp) {
    state = tabs.lalrtable.initState;
    stack.length = 1;
    stack.front = tuple(Token(tabs.symbols.startSymbol), state);
    commentDepth = 0;
    super.setInput(inp);
  }

  Message parse() {
    while (1) {
      if (inputStack.empty) {
        auto tok = super.getNextToken();
        inputStack ~= tok;
        auto skind = tabs.symbols[tok.symbol].kind;
        if (commentDepth == 0 && (skind == SymbolKind.Terminal || skind == SymbolKind.EndOfFile)) {
          return Message.TokenRead;
        }
      } else if (commentDepth > 0) {
        auto tok = inputStack.back;
        inputStack.popBack;
        switch (tabs.symbols[tok.symbol].kind) {
        case SymbolKind.CommentStart:
          ++commentDepth;
          break;
        case SymbolKind.CommentEnd:
          --commentDepth;
          break;
        case SymbolKind.EndOfFile:
          return Message.UnmatchedCommentError;
        default:
          break;
        }

      } else {
        auto tok = inputStack.back;
        switch (tabs.symbols[tok.symbol].kind) {
        case SymbolKind.Whitespace:
          inputStack.popBack;
          break;
        case SymbolKind.CommentStart:
          ++commentDepth;
          inputStack.popBack;
          break;
        case SymbolKind.CommentLine:
          // TODO: skip line but leave newline
          inputStack.popBack;
          break;

        case SymbolKind.Error:
          return Message.LexicalError;

        default:

          final switch (parseToken(tok)) {
          case ParseResult.Shift:
            inputStack.popBack;
            break;

          case ParseResult.Reduce:
            return Message.Reduction;

          case ParseResult.ReduceTrimmed:
            break;

          case ParseResult.Accept:
            return Message.Accept;

          case ParseResult.SyntaxError:
            return Message.SyntaxError;

          case ParseResult.InternalError:
            return Message.InternalError;
          }

        }
      }

    }
  }

  ParseResult parseToken(Token tok) {
    LALRAction action;
    if (findAction(tok.symbol, action)) {
      //      auto action = actions[entries.length];
      switch (action.type) {
      case ActionType.Accept:
        return ParseResult.Accept;

      case ActionType.Shift:
        stack ~= tuple(tok, state);
        state = action.target;
        return ParseResult.Shift;

      case ActionType.Reduce:
        auto rule = tabs.rules[action.target];
        ParseResult parseResult;
        Token head;
        head.symbol = rule.head;
        auto lookupState = stack[$ - rule.symbols.length][1];
        if (TrimReduction
            && rule.symbols.length == 1
            && tabs.symbols[rule.symbols[0]].kind == SymbolKind.NonTerminal) {
          head.data = stack.back[0].data;
          stack.popBack;
          parseResult = ParseResult.ReduceTrimmed;
        } else {
          Token[] children;
          foreach(ref item; stack[$ - rule.symbols.length .. $])
            children ~= item[0];
          stack.popBackN(rule.symbols.length);
          head.data = children;
          parseResult = ParseResult.Reduce;
        }
        assert(stack.length > 0);
        state = lookupState;
        LALRAction gotoAction;
        findAction(head.symbol, gotoAction) || assert(0);
        assert(gotoAction.type == ActionType.Goto);
        state = gotoAction.target;
        stack ~= tuple(head, lookupState);
        return parseResult;

      case ActionType.Goto: goto default;
      default:
        assert(0);
      }
    } else {
      return ParseResult.SyntaxError;
    }
  }

  bool findAction(SymbolRef sym, out LALRAction action) {
    auto actions = map!q{a.entry}(tabs.lalrtable[state].actions);
    assert(isSorted(actions));

    auto idx = binSearch(actions, sym);
    if (idx == size_t.max)
      return false;
    action = tabs.lalrtable[state].actions[idx];
    return true;
  }

  Tuple!(Token, LALRStateRef)[] stack;
  Token[] inputStack;
  LALRStateRef state;
  uint commentDepth;
}

size_t binSearch(Range, T)(Range range, T val) {
  size_t first = 0, count = range.length;
  while (count > 0) {
    immutable step = count / 2, it = first + step;
    if (range[it] < val) {
      first = it + 1;
      count -= step + 1;
    } else {
      count = step;
    }
  }
  if (first == range.length || range[first] != val)
    return size_t.max;
  return first;
}
