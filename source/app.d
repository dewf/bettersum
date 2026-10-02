import std.stdio;
import std.format;

import tokenizer;
import dtype;

import stonesoup.unit;
import stonesoup.sumtype;

mixin(sumtype(q{
ParseResult(T) {
	Success(`T` thing, `Location` loc, `Token[]` etc),
	Fail,
	Error(`string` message, `Location` loc)
}
}));

T tryToken(T)(Token[] input, int index, T delegate(Token*) func) { // delegate arg must be pointer/ref! otherwise it's a Token copy, and the .isWhatever methods will return pointers to temporary locations! memory corruption galore
	if (input.length > index) {
		return func(&input[index]);
	}
	return T.init;
}

ParseResult!DType parsePrimitive(Token[] tokens) {
	if (auto prim = tryToken(tokens, 0, t => t.isPrimitive())) {
		return ParseResult!DType.makeSuccess(new Primitive(*prim), tokens[0].loc, tokens[1..$]);
	}
	return ParseResult!DType.makeFail();
}

ParseResult!Unit parseSymbol(Token[] tokens, Token.Symbol which) {
	if (auto sym = tryToken(tokens, 0, t => t.isSymbol())) {
		if (*sym == which) {
			return ParseResult!Unit.makeSuccess(Unit(), tokens[0].loc, tokens[1..$]);
		}
	}
	return ParseResult!Unit.makeFail();
}

ParseResult!string parseNumeric(Token[] tokens) {
	if (auto num = tryToken(tokens, 0, t => t.isNumeric())) {
		return ParseResult!string.makeSuccess(*num, tokens[0].loc, tokens[1..$]);
	}
	return ParseResult!string.makeFail();
}

ParseResult!(Token[]) parseBetween(Token[] tokens, Token.Symbol left, Token.Symbol right) {
	import std.conv: to;
	import std.format;
	if (auto leftPtr = tryToken(tokens, 0, t => t.isSymbol())) {
		if (*leftPtr == left) {
			// scan until matching right
			int i = 1;
			int level = 1;
			while (i < tokens.length && level > 0) {
				if (auto sym = tokens[i].isSymbol()) {
					if (*sym == left) {
						level++;
					} else if (*sym == right) {
						level--;
						if (level == 0) {
							// done!
							return ParseResult!(Token[]).makeSuccess(tokens[1..i], tokens[0].loc, tokens[i+1 .. $]);
						}
					}
				} // else not a symbol, don't care
				i++;
			}
			// else never found matching :(
			return ParseResult!(Token[]).makeError(format("parseMatching: couldn't find closing %s", right.to!string), tokens[0].loc);
		}
	}
	return ParseResult!(Token[]).makeFail();
}

string[][string] wack;

ParseResult!DType parseBracketed(DType prim, Token[] tokens) {
	auto bracketResult = parseBetween(tokens, Token.Symbol.LeftBracket, Token.Symbol.RightBracket);
	if (auto bracketed = bracketResult.isSuccess()) {
		auto content = bracketed.thing;

		// what's the content?

		// empty content = dynamic array
		if (content.length == 0) {
			auto dt = new DynamicArray(prim);
			return ParseResult!DType.makeSuccess(dt, tokens[0].loc, bracketed.etc);
		}

		// numeric content = static array
		auto numericResult = parseNumeric(content);
		if (auto numeric = numericResult.isSuccess()) {
			// must have consumed everything:
			if (numeric.etc.length == 0) {
				auto dt = new StaticArray(prim, numeric.thing);
				return ParseResult!DType.makeSuccess(dt, tokens[0].loc, bracketed.etc);
			} else {
				return ParseResult!DType.makeError("spurious content after static array length", numeric.loc);
			}
		} // can fail, shouldn't ever error

		// type content = assoc array
		auto typeResult = parseType(content);
		if (auto type = typeResult.isSuccess()) {
			// must have consumed everything:
			if (type.etc.length == 0) {
				auto dt = new AssocArray(type.thing, prim);
				return ParseResult!DType.makeSuccess(dt, tokens[0].loc, bracketed.etc);
			} else {
				return ParseResult!DType.makeError("spurious content after assoc array key type", type.loc);
			}
		} else if (auto err = typeResult.isError()) {
			// raise error - problem parsing nested type
			return ParseResult!DType.makeError(err.message, err.loc);
		}

		// unhandled bracketed content
		return ParseResult!DType.makeError("unknown bracketed content", bracketed.loc);

	} else if (auto err = bracketResult.isError()) {
		// raise bracket errors
		return ParseResult!DType.makeError(err.message, err.loc);
	}

	// else no worries
	return ParseResult!DType.makeFail();
}

ParseResult!DType parseFront(Token[] tokens) {
	// one of:

	// - primitive
	if (auto prim = tryToken(tokens, 0, t => t.isPrimitive())) {
		auto dt = new Primitive(*prim);
		return ParseResult!DType.makeSuccess(dt, tokens[0].loc, tokens[1..$]);
	}

	// - named thing
	if (auto id = tryToken(tokens, 0, t => t.isIdentifier())) {
		throw new Exception("parseFront: not yet implemented");
	}

	// else error, didn't find what we needed
	return ParseResult!DType.makeFail();
}

ParseResult!DType parseTypeSuffix(DType front, Location loc, Token[] tokens) {
	// one of:

	// - array suffix (recurse on content, depending)
	auto bracketedResult = parseBracketed(front, tokens);
	if (auto bracketed = bracketedResult.isSuccess()) {
		// need to recurse to see if there is more of a suffix
		return parseTypeSuffix(bracketed.thing, bracketed.loc, bracketed.etc);

	} else if (auto err = bracketedResult.isError()) {
		// raise error
		return bracketedResult;
	}

	// - 'delegate' / 'function' + (args) + pure/nothrow/@safe/etc

	// - none of the above - that's fine, means the type is complete (probably)
	return ParseResult!DType.makeSuccess(front, loc, tokens);
}

ParseResult!DType parseType(Token[] tokens) {
	if (tokens.length == 0) return ParseResult!DType.makeFail();

	auto frontResult = parseFront(tokens);
	if (auto front = frontResult.isSuccess()) {
		// now pass to the suffix handler, which is recursive
		return parseTypeSuffix(front.thing, front.loc, front.etc);
	} else {
		// failure = error, because it's required
		return ParseResult!DType.makeError("failed to parse 'front' part of D type", tokens[0].loc);
	}

	// else not even that
	return ParseResult!DType.makeFail();
}

void main()
{
	auto tokens = tokenize("int[][string] varname");
	foreach (t; tokens) {
		writefln("token: %s", t);
	}

	// writeln("====================");
	parseType(tokens).match!void(
		(auto success) {
			writefln("DType: %s", success.thing);
			writeln("===== remaining tokens =====");
			foreach (t; success.etc) {
				writefln(" - %s", t);
			}
		},
		(auto fail) {},
		(auto error) {}
	);
}
