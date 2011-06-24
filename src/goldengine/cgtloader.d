module goldengine.cgtloader;

import std.exception, std.stream, std.system, std.typecons, std.variant;

struct Empty {}

CGTable loadFromFile(string path) {
  auto cgfile = new BufferedFile(path);
  auto cgttable = new CGTable;
  enforce(getImpl!string(cgfile) == "GOLD Parser Tables/v1.0", "corrupt cgt file");
  while (!cgfile.eof) {
    cgttable.getRec(cgfile);
  }
  return cgttable;
}

class CGTable {
  void getRec(InputStream stream) {
    enforce(stream.getc() == 'M', "corrupt cgt file");
    uint nentries = stream.getcw();
    static if (std.system.endian == Endian.BigEndian)
      nentries = core.bitop.bswap(nentries);

    switch (get!byte(stream)) {
    case 'P':
      // @@BUG@@ Params(gets!(string, string)(stream).tupleof) calls gets twice
      auto args = gets!(string, string, string, string, bool, int)(stream);
      this.params = Params(args.tupleof);
      break;

    case 'T':
      auto nsym = get!int(stream);
      auto nchs = get!int(stream);
      auto nrules = get!int(stream);
      auto ndfastates = get!int(stream);
      auto nlalrstates = get!int(stream);

      this.symbols.length = nsym;
      this.charsets.length = nchs;
      this.rules.length = nrules;
      this.dfastates.length = ndfastates;
      this.lalrstates.length = nlalrstates;
      break;

    case 'C':
      auto idx = get!int(stream);
      this.charsets[idx] = get!dstring(stream);
      break;

    case 'S':
      auto idx = get!int(stream);
      auto args = gets!(string, int)(stream);
      this.symbols[idx] = Symbol(args[0], cast(Symbol.Kind)args[1]);
      break;

    case 'R':
      auto idx = get!int(stream);
      auto rule = Rule(get!int(stream));
      get!Empty(stream);
      rule.chsymidxs = get!(int[])(stream);
      this.rules[idx] = rule;
      break;

    case 'I':
      this.initDFAState = get!int(stream);
      this.initLALRState = get!int(stream);
      break;

    case 'D':
      auto idx = get!int(stream);
      auto args = gets!(bool, int)(stream);
      auto state = DFAState(args.tupleof);
      get!Empty(stream);
      state.edges = get!(DFAEdge[])(stream);
      this.dfastates[idx] = state;
      break;

    case 'L':
      auto idx = get!int(stream);
      auto state = LALRState();
      get!Empty(stream);
      state.actions = get!(LALRAction[])(stream);
      this.lalrstates[idx] = state;
      break;

    default:
      throw new Exception("corrupt cgt file");
    }
  }

  int initDFAState, initLALRState;
  Params params;
  Symbol[] symbols;
  dstring[] charsets;
  Rule[] rules;
  DFAState[] dfastates;
  LALRState[] lalrstates;
}

struct Params { string name, ver, auth, about; bool caseSens; int startSymidx; }
struct Symbol { string name; Kind kind; enum Kind { NTerm, Term, WS, EOF, CmtS, CmtE, CmtL, Error } }
struct Rule { int symidx; int[] chsymidxs; }
struct DFAState { bool acc; int accsymidx; DFAEdge[] edges; }
struct DFAEdge { int charsetidx, targetidx; }
struct LALRState { LALRAction[] actions; }
struct LALRAction { int symbolidx; Action action; int targetidx; enum Action { Shift, Reduce, Goto, Accept } }

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
  else static if (is(T == int)) enum typeLetter = 'I';
  else static if (is(T == string)) enum typeLetter = 'S';
  else static if (is(T == dstring)) enum typeLetter = 'S';

  // edges will end when a byte comes along so we might say int is their id
  else static if (is(T == DFAEdge)) enum typeLetter = typeLetter!int;
  else static if (is(T == LALRAction)) enum typeLetter = typeLetter!int;
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

int getImpl(T : int)(InputStream stream) {
  auto val = cast(int)stream.getcw();
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
  auto csidx = getImpl!int(stream); // int header already gone
  auto tidx = get!int(stream);
  get!Empty(stream);
  return DFAEdge(csidx, tidx);
}

LALRAction getImpl(T : LALRAction)(InputStream stream) {
  auto sidx = getImpl!int(stream); // int header already gone
  auto action = cast(LALRAction.Action)get!int(stream);
  auto tidx = get!int(stream);
  get!Empty(stream);
  return LALRAction(sidx, action, tidx);
}
