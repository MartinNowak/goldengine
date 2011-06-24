import std.stdio;
import goldengine.cgtloader;

void main(string[] args) {
  foreach(arg; args[1..$]) {
    auto table = loadFromFile(arg);
    writeln(table.tupleof);
  }
}