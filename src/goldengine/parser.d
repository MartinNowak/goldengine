module goldengine.parser;

import std.algorithm, std.exception, std.range, std.typecons;
import goldengine.constants, goldengine.cgtloader, goldengine.datatypes, goldengine.lexer;

Parser mkParser(CGTables tables) {
  auto parser = Parser(mkLexer(tables), tables.lalrtable, tables.rules, tables.symbols);
  parser.reset();
  return parser;
}

struct Parser {
  enum TrimReduction = true;

  void reset() {
    state = states.initState;
    stack.length = 1;
    stack.front = tuple(Token(symbols.startSymbol), state);
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
        auto rule = rules[action.target];
        ParseResult parseResult;
        Token head;
        head.symbol = rule.head;
        auto lookupState = stack[$-rule.symbols.length][1];
        if (TrimReduction
            && rule.symbols.length == 1
            && symbols[rule.symbols[0]].kind == SymbolKind.NonTerminal) {
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
        stack ~= tuple(head, state);
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
    auto actions = states[state].actions;

    size_t first = 0, count = actions.length;
    while (count > 0) {
      immutable step = count / 2, it = first + step;
      if (actions[it].entry < sym) {
        first = it + 1;
        count -= step + 1;
      } else {
        count = step;
      }
    }
    if (first == actions.length || actions[first].entry != sym)
      return false;
    action = actions[first];
    return true;
  }

  Lexer lexer;
  LALRStateTable states;
  RuleTable rules;
  SymbolTable symbols;
  LALRStateRef state;
  Tuple!(Token, LALRStateRef)[] stack;
}
