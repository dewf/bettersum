import std.stdio;
import std.format;

import tokenizer;
import typeparser: parseType;
import dtype: renderToString;

struct Foo(T) {
	T y;
}

struct Woot(T) {
	T x;
	struct Subwoot {}
	Subwoot sub;
}

int[string] x;
Woot!(typeof(x)) nice;
const(Woot!int.Subwoot)[] york111;

string[] examples = [
	q{int},
	q{int[]},
	q{ulong[string]},
	q{Woot!(void function(ref const int[]))[string]},
	q{const shared string[int]*[void delegate(Woot!int x) nothrow @safe]},
	//
    q{string[10_000]},
    q{int},
    q{string},
    q{uint},
    q{long},
    q{double},
    q{char},
	//
    q{int*},
    q{int**},
    q{int[]},
    q{int[10]},
    q{int[10][20]},
    q{int[string]},
	//
    q{const(int)},
    q{immutable(int)},
    q{shared(int)},
    q{const(int*)},
    q{immutable(int[])},
    q{const(int[int])},
    q{shared(const(int*))},
    q{const(immutable(int*))},
	//
    q{int function()},
    q{int function(int)},
    q{int function(int, string)},
    q{int delegate(int)},
    q{void function(int, double)},
    q{int* function(int*)},
    q{int[] function(int[int])},
    q{int function(int function(int))},
	//
    q{int**[]},
    q{int[][10]},
    q{int[10][]},
    q{int[int[]]},
    q{int[][int]},
    q{const(int*)[]},
    q{const(int[]*)},
    q{immutable(int[int])*},
    q{shared(const(int**[]))},
    q{int function(int*)[]},
    q{int[] function(int[int])},
    q{int function(int function(int*), int[])},
	//
    q{const(int*[])[10]},
    q{immutable(int[int[]])*},
    q{int function(int function(int)[], int[int]*)},
    q{const(int function(int*)[])},
    q{int[] function(int[] function(int*))},
    q{shared(const(immutable(int**[])))[10]},
    q{int function(int function(int function(int)))},
    q{int[int[]][10]},
    q{const(int function(int[int])*)},
    q{int function(const(int*)[], immutable(int[int])*)[]},
	//
    q{int[string]},
    q{const(int[])},
    q{const(const int[])},
    q{foo!(int,string)[]},
    q{const(int delegate(int) pure nothrow[])},
    q{typeof(`foo!(T).bar`)},
    q{int function(int, int) pure nothrow @safe},
    // q{const(Woot!int.Subwoot)[])},
];

void main()
{
	import std.string: replace;

	foreach (e; examples) {
		writefln("parsing [%s]", e);
		auto tokens = tokenize(e);
		parseType(tokens).match!void(
			(auto success) {
				auto compareWith = e.replace("`", ""); // strip out backticks for the purpose of comparison
				auto rendered = success.thing.renderToString();
				if (rendered != compareWith) {
					writefln("rendered: %s", rendered);
					assert(0, "parsed + rendered thing failed to match original");
				}
			},
			(auto fail) {
				assert(0, "failed to parse a type");
			},
			(auto error) {
				assert(0, "error parsing type");
				// writefln("parse error: { %s } %s", error.message, error.loc);
			}
		);
	}
	// // writeln("====================");
	// parseType(tokens).match!void(
	// 	(auto success) {
	// 		success.thing.prettyPrint("");
	// 		writeln("===== remaining tokens =====");
	// 		foreach (t; success.etc) {
	// 			writefln(" - %s", t);
	// 		}
	// 		writeln("============================");
	// 		writefln("output: { %s }", renderToString(success.thing));
	// 	},
	// 	(auto fail) {
	// 		writefln("failed to parse a type");
	// 	},
	// 	(auto error) {
	// 		writefln("parse error: { %s } %s", error.message, error.loc);
	// 	}
	// );
}
