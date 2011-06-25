module goldengine.parser;

import std.algorithm, std.exception, std.range, std.variant;
import goldengine.constants, goldengine.cgtloader, goldengine.datatypes;

class Parser {
  this(CGTable table) {
    //    enforce(table.params.caseSens, "case insensitive grammars unsupported");
    this.table = table;
  }

  CGTable table;
  string data;
}
