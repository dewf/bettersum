module bettersum.parsecommon;

import bettersum.tokenizer;

// TODO: remove
import stonesoup.unit;
import stonesoup.sumtype;

mixin(sumtype(q{
ParseResult(T) {
	Success(`T` thing, `Location` loc, `Token[]` etc),
	Fail,
	Error(`string` message, `Location` loc)
}
}));

mixin(sumtype(q{
SimpleResult(T) {
	Success(`T` thing, `Location` loc, `Token[]` etc),
	Fail
}
}));

ParseResult!T reraise(T)(string message, Location loc) {
	return ParseResult!T.makeError(message, loc);
}

T tryToken(T)(Token[] input, int index, T delegate(Token*) func) { // delegate arg must be pointer/ref! otherwise it's a Token copy, and the .isWhatever methods will return pointers to temporary locations! memory corruption galore
	if (index < input.length) {
		return func(&input[index]);
	}
	return T.init;
}

SimpleResult!Unit parseKeyword(Token[] tokens, string which) {
	if (auto kw = tryToken(tokens, 0, t => t.isKeyword())) {
		if (*kw == which) {
			return SimpleResult!Unit.makeSuccess(Unit(), tokens[0].loc, tokens[1..$]);
		}
	}
	return SimpleResult!Unit.makeFail();
}

SimpleResult!string parseOneOfKeywords(Token[] tokens, string[] keywords) {
	import std.algorithm.searching: canFind;
	if (auto kw = tryToken(tokens, 0, t => t.isKeyword())) {
		if (keywords.canFind(*kw)) {
			return SimpleResult!string.makeSuccess(*kw, tokens[0].loc, tokens[1..$]);
		}
		// else was some other keyword, no biggie -- fall through to failure
	}
	return SimpleResult!string.makeFail();
}

SimpleResult!Unit parseSymbol(Token[] tokens, Token.Symbol which) {
	if (auto sym = tryToken(tokens, 0, t => t.isSymbol())) {
		if (*sym == which) {
			return SimpleResult!Unit.makeSuccess(Unit(), tokens[0].loc, tokens[1..$]);
		}
	}
	return SimpleResult!Unit.makeFail();
}

SimpleResult!string parseIdentifier(Token[] tokens) {
	if (auto id = tryToken(tokens, 0, t => t.isIdentifier())) {
		return SimpleResult!string.makeSuccess(*id, tokens[0].loc, tokens[1..$]);
	}
	return SimpleResult!string.makeFail();
}

SimpleResult!string parseQualifiedName(Token[] tokens) {
	string[] parts;
	int i;
	while (i < tokens.length) {
		if (auto id = tryToken(tokens, i, t => t.isIdentifier())) {
			parts ~= *id;
			i++;

			// if there's a '.' following, we can continue
			if (auto sym = tryToken(tokens, i, t => t.isSymbol())) {
				if (*sym == Token.Symbol.Dot) {
					// cool, continue
					i++;
					continue;
				}
				// something other than dot, fall through
			}
			// no symbol found, fall through
		}
		// no identifier - time to stop
		break;
	}
	if (parts.length > 0) {
		import std.range: join;
		auto joined = parts.join(".");
		return SimpleResult!string.makeSuccess(joined, tokens[0].loc, tokens[i..$]);
	}
	return SimpleResult!string.makeFail();
}

SimpleResult!string parseNumeric(Token[] tokens) {
	if (auto num = tryToken(tokens, 0, t => t.isNumeric())) {
		return SimpleResult!string.makeSuccess(*num, tokens[0].loc, tokens[1..$]);
	}
	return SimpleResult!string.makeFail();
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
