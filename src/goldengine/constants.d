module goldengine.constants;

enum SymbolKind {
  NonTerminal = 0,
  Terminal = 1,
  Whitespace = 2,
  EndOfFile = 3,
  CommentStart = 4,
  CommentEnd = 5,
  CommentLine = 6,
  Error = 7,
}

enum SpecialSymbol {
  EndOfFile = 0,
  Error = 1,
  WhiteSpace = 2,
}

enum ActionType {
  Shift = 1,
  Reduce = 2,
  Goto = 3,
  Accept = 4,
}

enum ParseResult {
  Shift,
  Reduce,
  ReduceTrimmed,
  Accept,
  SyntaxError,
  InternalError,
}

enum Message {
  TokenRead,
  Reduction,
  Accept,

  NotLoadedError,
  LexicalError,
  SyntaxError,

  RunawayCommentError,
  UnmatchedCommentError,

  InternalError,
}
