module goldengine.cgtloader;

import std.algorithm, std.exception, std.stream, std.system, std.typecons, std.variant;
import goldengine.constants, goldengine.datatypes;

struct Empty {}

CGTables loadFromFile(string path) {
  auto cgfile = new BufferedFile(path);
  CGTables cgttable;
  enforce(getImpl!string(cgfile) == "GOLD Parser Tables/v1.0", "corrupt cgt file");
  while (!cgfile.eof) {
    cgttable.parseRec(cgfile);
  }
  return cgttable;
}

struct CGTables {
  void parseRec(InputStream stream) {
    enforce(stream.getc() == 'M', "corrupt cgt file");
    uint nentries = stream.getcw();
    static if (std.system.endian == Endian.BigEndian)
      nentries = core.bitop.bswap(nentries);

    switch (get!byte(stream)) {
    case 'P':
      // @@BUG@@ Params(gets!(string, string)(stream).tupleof) calls gets twice
      auto args = gets!(string, string, string, string, bool)(stream);
      SymbolRef startSymbol = get!uint(stream);
      this.params = Params(args.tupleof);
      this.symbols.startSymbol = startSymbol;
      break;

    case 'T':
      auto nsym = get!uint(stream);
      auto nchs = get!uint(stream);
      auto nrules = get!uint(stream);
      auto ndfastates = get!uint(stream);
      auto nlalrstates = get!uint(stream);

      this.symbols.length = nsym;
      this.charsets.length = nchs;
      this.rules.length = nrules;
      this.dfatable.entries.length = ndfastates;
      this.lalrtable.entries.length = nlalrstates;
      break;

    case 'C':
      auto idx = get!uint(stream);
      this.charsets[idx] = get!dstring(stream);
      break;

    case 'S':
      auto idx = get!uint(stream);
      auto args = gets!(string, uint)(stream);
      this.symbols[idx] = Symbol(args[0], cast(SymbolKind)args[1]);
      //      std.stdio.writefln("Symbol idx:%s kind:%s name:%s", idx, cast(SymbolKind)args[1], args[0]);
      break;

    case 'R':
      auto idx = get!uint(stream);
      auto rule = Rule(get!uint(stream));
      get!Empty(stream);
      rule.symbols = get!(uint[])(stream);
      this.rules[idx] = rule;
      break;

    case 'I':
      this.dfatable.initState = get!uint(stream);
      this.lalrtable.initState = get!uint(stream);
      break;

    case 'D':
      auto idx = get!uint(stream);
      auto args = gets!(bool, uint)(stream);
      auto state = DFAState(args.tupleof);
      get!Empty(stream);
      state.edges = get!(DFAEdge[])(stream);
      this.dfatable[idx] = state;
      break;

    case 'L':
      auto idx = get!uint(stream);
      auto state = LALRState();
      get!Empty(stream);
      state.actions = sort!q{a.entry < b.entry}(get!(LALRAction[])(stream)).release;
      this.lalrtable[idx] = state;
      break;

    default:
      throw new Exception("corrupt cgt file");
    }
  }

  static struct Params { string name, ver, auth, about; bool caseSens; }
  Params params;

  CharSetTable charsets;
  DFAStateTable dfatable;

  SymbolTable symbols;
  RuleTable rules;
  LALRStateTable lalrtable;
}

T get(T)(InputStream stream) {
  enforce(stream.getc() == typeLetter!T, "corrupt cgt file");
  return getImpl!T(stream);
}

Tuple!(Ts) gets(Ts...)(InputStream stream) {
  typeof(return) res;
  foreach(i, T; Ts)
    res[i] = get!T(stream);
  return res;
}

T[] get(T : T[])(InputStream stream) if (!(is(T[] == string) || is(T[] == dstring))) {
  T[] res;
  while (1) {
    auto c = stream.getc();
    if (c != typeLetter!T) {
      stream.ungetc(c);
      return res;
    }
    res ~= getImpl!T(stream);
  }
}

template typeLetter(T) {
  static if (is(T == Empty)) enum typeLetter = 'E' ;
  else static if (is(T == bool)) enum typeLetter = 'B';
  else static if (is(T == byte)) enum typeLetter = 'b';
  else static if (is(T == uint)) enum typeLetter = 'I';
  else static if (is(T == string)) enum typeLetter = 'S';
  else static if (is(T == dstring)) enum typeLetter = 'S';

  // edges will end when a byte comes along so we might say int is their id
  else static if (is(T == DFAEdge)) enum typeLetter = typeLetter!uint;
  else static if (is(T == LALRAction)) enum typeLetter = typeLetter!uint;
}

Empty getImpl(T : Empty)(InputStream stream) {
  return Empty();
}

bool getImpl(T : bool)(InputStream stream) {
  auto c = stream.getc();
  if (c == 1)
    return true;
  else if (c == 0)
    return false;
  else
    throw new Exception("corrupt cgt file");
}

byte getImpl(T : byte)(InputStream stream) {
  return stream.getc();
}

uint getImpl(T : uint)(InputStream stream) {
  auto val = cast(int)stream.getcw();
  assert(val >= 0); // actually signed ints, but no negative values
  static if (std.system.endian == Endian.BigEndian)
    val = core.bitop.bswap(val);
  return val;
}

string getImpl(T : string)(InputStream stream) {
  wstring str;
  while (!stream.eof) {
    auto cw = stream.getcw();
    if (cw == 0)
      return std.conv.to!string(str);
    str ~= cw;
  }
  throw new Exception("corrupt cgt file");
}

dstring getImpl(T : dstring)(InputStream stream) {
  dstring str;
  while (!stream.eof) {
    dchar cw = stream.getcw();
    if (cw == 0)
      return str;
    str ~= cw;
  }
  throw new Exception("corrupt cgt file");
}

DFAEdge getImpl(T : DFAEdge)(InputStream stream) {
  auto csidx = getImpl!uint(stream); // int header already gone
  auto tidx = get!uint(stream);
  get!Empty(stream);
  return DFAEdge(csidx, tidx);
}

LALRAction getImpl(T : LALRAction)(InputStream stream) {
  auto sidx = getImpl!uint(stream); // int header already gone
  auto action = cast(ActionType)get!uint(stream);
  auto tidx = get!uint(stream);
  get!Empty(stream);
  return LALRAction(sidx, action, tidx);
}
