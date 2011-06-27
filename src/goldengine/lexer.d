module goldengine.lexer;

import std.algorithm, std.exception, std.range, std.stream, std.stdio, std.utf;
import core.memory;
import goldengine.cgtloader, goldengine.datatypes, goldengine.constants;
version(Windows) import std.c.windows.windows;

class Lexer {
  this(CGTables tabs) {
    this.tabs = tabs;
  }

  void setInputText(string text, string textName="text input") {
    this.resetState();
    this._input = new TArrayStream!string(text);
    this._fileno = std.conv.to!uint(_filenames.length);
    _filenames ~= textName;
  }

  void setInputFile(string path) {
    this.resetState();
    this._input = new BufferedFile(path);
    this._fileno = std.conv.to!uint(_filenames.length);
    _filenames ~= path;
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
            auto errlexem = curline[0 .. len + std.utf.codeLength!char(ch)];
            tok.data = errlexem;
            this.reportError(errlexem);
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
    prefix.fileno = _fileno;
    prefix.lineno = _lineno;
    prefix.delim = 0;

    char[] nline;
    do {
      ++_lineno;
      nline = _input.readLine(readbuf);
    } while (nline.empty && !_input.eof);
    readbuf = nline;
    string annline = cast(string)(prefix.data ~ nline ~ '\0');
    assert(!std.exception.pointsTo(readbuf, annline));
    return annline[prefix.sizeof .. $-1];
  }

  void reportError(string s) {
    auto blk = GC.query(s.ptr);
    immutable(char)* linestart = s.ptr, lineend = s.ptr + s.length;
    while (*linestart != 0 && linestart > blk.base) {
      --linestart;
    }
    while (*lineend != 0 && lineend < blk.base + blk.size) {
      ++lineend;
    }
    enforce(linestart >= blk.base + 2 * uint.sizeof && lineend < blk.base + blk.size,
      "can't report error for copied strings");
    uint fileno = *cast(uint*)(linestart - 2 * uint.sizeof);
    uint lineno = *cast(uint*)(linestart - 1 * uint.sizeof);
    stderr.writefln(`Error in "%s" at line %s at pos %s:`,
      getFileName(fileno), lineno, s.ptr - linestart);

    version (Windows) {
      auto hcon = GetStdHandle(STD_ERROR_HANDLE);
      if (hcon == INVALID_HANDLE_VALUE)
        stderr.writeln(linestart[0 .. lineend - linestart]);
      else {
        CONSOLE_SCREEN_BUFFER_INFO info;
        GetConsoleScreenBufferInfo(hcon, &info);
        stderr.write(linestart[0 .. s.ptr - linestart]);
        SetConsoleTextAttribute(hcon, FOREGROUND_RED);
        stderr.write(s);
        SetConsoleTextAttribute(hcon, info.wAttributes);
        stderr.writeln((s.ptr + s.length)[0 .. lineend - s.ptr - s.length]);
      }
    } else {
      stderr.writefln("%s\033[01;31m%s\033[0;m%s",
        linestart[0 .. s.ptr - linestart],
        s,
        (s.ptr + s.length)[0 .. lineend - s.ptr - s.length]);
    }
    stderr.writeln(repeat(' ', s.ptr - linestart), "^--- here");
  }

  string getFileName(uint fileno) {
    enforce(fileno < _filenames.length, "unknown fileno");
    return _filenames[fileno];
  }

  protected void resetState() {
    _input = null;
    curline = null;
    _fileno = 0;
    _lineno = 0;
  }

  CGTables tabs;
  InputStream _input;
  string curline;
  char[] readbuf;
  uint _fileno, _lineno;
  static string[] _filenames;
}
