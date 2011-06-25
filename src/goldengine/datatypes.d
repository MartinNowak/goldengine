module goldengine.datatypes;

import std.variant;
import goldengine.constants;

// Symbols
struct Symbol {
  string name;
  SymbolKind kind;
  //  Symbol* match;
}

alias int SymbolRef;
struct SymbolTable {
  alias entries this;
  Symbol[] entries;
}

// Rules
struct Rule {
  SymbolRef head;
  SymbolRef[] symbols;
}

alias int RuleRef;
struct RuleTable {
  alias entries this;
  Rule[] entries;
}

struct Reduction {
  RuleRef rule;
  Token[] tokens;
}

// Token
struct Token {
  SymbolRef symbol;
  Variant data;
}

// LALR
struct LALRState {
  LALRAction[] actions;
}

alias uint LALRStateRef;
struct LALRStateTable {
  alias entries this;
  LALRState[] entries;
}

struct LALRAction {
  SymbolRef entry;
  ActionType type;
  LALRStateRef target;
}

// DFA
struct DFAState {
  bool isAccepting;
  SymbolRef acceptSymbol;
  DFAEdge[] edges;
}

alias uint DFAStateRef;
struct DFAStateTable {
  alias entries this;
  DFAState[] entries;
}

alias int CharSetRef;
struct CharSetTable {
  alias entries this;
  dstring[] entries;
}

struct DFAEdge {
  CharSetRef charset;
  DFAStateRef targetState;
}
