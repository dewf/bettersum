import std.stdio;
import std.format;

import tokenizer;

struct ParseResult(T) {
	bool _success;
	T thing;
	Token[] etc;

	bool opCast(X : bool)() const {
		return _success;
	}

	static ParseResult success(T thing, Token[] etc) {
		return ParseResult!T(true, thing, etc);
	}

	static ParseResult fail() {
		return ParseResult!T(false);
	}
}

struct DType {
	enum Tag {
		Primitive // of string
	}
	union Content {
		string text;
	}
	Tag tag;
	Content content;

	static DType mkPrimitive(string prim) {
		Content c = { text: prim };
		return DType(Tag.Primitive, c);
	}

	string toString() const {
		final switch (tag) {
			case Tag.Primitive:
				return format("Prim:%s", content.text);
		}
	}
}
alias DTypeParseResult = ParseResult!DType;

DTypeParseResult parseType(Token[] tokens) {
	if (tokens.length == 0) return DTypeParseResult.fail();
	if (auto prim = tokens[0].isPrimitive()) {
		return DTypeParseResult.success(DType.mkPrimitive(*prim), tokens[1..$]);
	}
	return DTypeParseResult.fail();
}

void main()
{
	auto tokens = tokenize("int varname");
	// foreach (t; tokens) {
	// 	writefln("token: %s", t);
	// }
	// writeln("====================");
	if (auto res = parseType(tokens)) {
		writefln("DType: %s", res.thing);
		writeln("===== remaining tokens =====");
		foreach (t; res.etc) {
			writefln(" - %s", t);
		}
	}
}
