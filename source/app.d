import std.stdio;

import tokenizer;

auto x = q{
CoolThing(T) {
	One(int),
	Two(string x),
	Three(string x, int y)
}
};

auto examples = [
	"int x",
	"string y",
	"int[] things",
	"int[string] mappy",
	"const(int[]) things",
	"const(const int[]) things",
	"foo!(int, string)[] variablename",
	"const (int delegate(int) pure nothrow[]) variablename",
	"typeof(foo!(T).bar) variablename",
	"int function(int, int) pure nothrow @safe variablename",
	"ref const(Structy!int.Substruct[]) variablename",
	// "CoolThing
    //     { One, Two(int x), Three(int),
    //       Four, Five(int x, int y, int z) }"
];

struct Bar(T) {
	T x;
}

struct Foo(T,Y) {
	T bar;
	Y foog;
	typeof(Bar!(T).x) yack;
}

void main()
{
	const (int delegate(int) pure nothrow[]) variablename;
	const(const int[]) things;
	Foo!(int,string)[] morely;
	const (int delegate(int)[]) yeargh;
	typeof(Foo!(int,string).bar) yeargh2;
	int function(int, int) pure nothrow @safe woot;

	foreach (e; examples) {
		writefln("==== example { %s } =====", e);
		foreach (token; tokenize(e)) {
			writefln("token: %s", token);
		}
	}
}
