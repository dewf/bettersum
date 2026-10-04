import std.stdio;
import std.format;

import tokenizer;
import typeparser: parseType;

void main()
{
	auto tokens = tokenize("Woot!int[][string] delegate(ref string y) derp");
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
		},
		(auto fail) {
			writefln("failed to parse a type");
		},
		(auto error) {
			writefln("parse error: { %s } %s", error.message, error.loc);
		}
	);
}
