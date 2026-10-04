import std.stdio;
import std.format;

import tokenizer;
import typeparser: parseType;
import dtype: renderToString;

struct Woot(T) {
	T x;
}

const shared string[int]*[void delegate(Woot!int x) nothrow @safe] derp;

void main()
{
	auto tokens = tokenize(q{const shared string[int]*[`void delegate(Woot!int x) nothrow @safe`] derp});
	// foreach (t; tokens) {
	// 	writefln("token: %s", t);
	// }

	// writeln("====================");
	parseType(tokens).match!void(
		(auto success) {
			success.thing.prettyPrint("");
			writeln("===== remaining tokens =====");
			foreach (t; success.etc) {
				writefln(" - %s", t);
			}
			writeln("============================");
			writefln("output: { %s }", renderToString(success.thing));
		},
		(auto fail) {
			writefln("failed to parse a type");
		},
		(auto error) {
			writefln("parse error: { %s } %s", error.message, error.loc);
		}
	);
}
