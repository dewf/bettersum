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

ParseResult!U reraise(U,T)(ParseResult!T original) {
	return ParseResult!U.makeError(original.error.message, original.error.loc);
}

T tryToken(T)(Token[] input, int index, T delegate(Token*) func) { // delegate arg must be pointer/ref! otherwise it's a Token copy, and the .isWhatever methods will return pointers to temporary locations! memory corruption galore
	if (input.length > index) {
		return func(&input[index]);
	}
	return T.init;
}

// TODO: change those of these which can't have errors, to something simpler than ParseResult?
// maybe SimpleParseResult? or should Fail() have its own payload?

ParseResult!DType parsePrimitive(Token[] tokens) {
	if (auto prim = tryToken(tokens, 0, t => t.isPrimitive())) {
		return ParseResult!DType.makeSuccess(new Primitive(*prim), tokens[0].loc, tokens[1..$]);
	}
	return ParseResult!DType.makeFail();
}

ParseResult!Unit parseKeyword(Token[] tokens, string which) {
	if (auto kw = tryToken(tokens, 0, t => t.isKeyword())) {
		if (*kw == which) {
			return ParseResult!Unit.makeSuccess(Unit(), tokens[0].loc, tokens[1..$]);
		}
	}
	return ParseResult!Unit.makeFail();
}

ParseResult!string parseOneOfKeywords(Token[] tokens, string[] keywords) {
	import std.algorithm.searching: canFind;
	if (auto kw = tryToken(tokens, 0, t => t.isKeyword())) {
		if (keywords.canFind(*kw)) {
			return ParseResult!string.makeSuccess(*kw, tokens[0].loc, tokens[1..$]);
		}
		// else was some other keyword, no biggie -- fall through to failure
	}
	return ParseResult!string.makeFail();
}

ParseResult!Unit parseSymbol(Token[] tokens, Token.Symbol which) {
	if (auto sym = tryToken(tokens, 0, t => t.isSymbol())) {
		if (*sym == which) {
			return ParseResult!Unit.makeSuccess(Unit(), tokens[0].loc, tokens[1..$]);
		}
	}
	return ParseResult!Unit.makeFail();
}

ParseResult!string parseIdentifier(Token[] tokens) {
	if (auto id = tryToken(tokens, 0, t => t.isIdentifier())) {
		return ParseResult!string.makeSuccess(*id, tokens[0].loc, tokens[1..$]);
	}
	return ParseResult!string.makeFail();
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
			// re-raise (same type)
			return typeResult;
		}

		// unhandled bracketed content
		return ParseResult!DType.makeError("unknown bracketed content", bracketed.loc);

	} else if (auto err = bracketResult.isError()) {
		// raise bracket errors
		return reraise!DType(bracketResult);
	}

	// else no worries
	return ParseResult!DType.makeFail();
}

ParseResult!(DType[]) parseTypeArguments(Token[] tokens) {

	// required !
	auto bangResult = parseSymbol(tokens, Token.Symbol.Bang);
	if (bangResult.isFail()) {
		// no type args ...
		return ParseResult!(DType[]).makeFail();
	} // error not possible for parseSymbol

	// redefine for convenience
	tokens = bangResult.success.etc;

	// is it a single type?
	auto singleTypeResult = parseType(tokens, false); // don't follow suffix (for this variant)
	if (auto single = singleTypeResult.isSuccess()) {
		return ParseResult!(DType[]).makeSuccess([single.thing], single.loc, single.etc);
	} else if (auto err = singleTypeResult.isError()) {
		// re-raise
		return reraise!(DType[])(singleTypeResult);
	} // else simple failure - try parenthesized parse instead

	// else is it a parenthesized list?
	auto parensResult = parseBetween(tokens, Token.Symbol.LeftParen, Token.Symbol.RightParen);
	if (auto content = parensResult.isSuccess()) {
		// parse comma-delimited list of types
		DType[] types;
		auto input = content.thing;
		while (input.length > 0) {

			auto typeResult = parseType(input);
			if (auto type = typeResult.isSuccess()) {

				types ~= type.thing;
				input = type.etc;

				// parse comma or verify input end and return
				if (input.length > 0) {

					auto commaResult = parseSymbol(input, Token.Symbol.Comma);
					if (auto comma = commaResult.isSuccess()) {
						// excellent!
						input = comma.etc;
						continue;
					} // no errors possible for symbol parsing

					// else whoops
					return ParseResult!(DType[]).makeError("missing comma in type args list", input[0].loc); // input.length > 0 branch, so should be OK

				} else {
					// done reading all content - happy exit
					return ParseResult!(DType[]).makeSuccess(types, type.loc, content.etc); // content.etc = post-parens content
				}

			} else if (auto err = typeResult.isError()) {
				// raise type-parsing error
				return reraise!(DType[])(typeResult);
			}

			// else it's an error because we failed to parse a type (and didn't continue/exit first)
			return ParseResult!(DType[]).makeError("parseTypeArguments: failed to parse a type", input[0].loc); // input.length > 0, so should be OK
		}
		throw new Exception("parseTypeArguments(): unreachable");

	} else if (auto err = parensResult.isError()) {
		// raise error (requires conversion)
		return reraise!(DType[])(parensResult);
	}
	// no parens pair, fail gracefully
	return ParseResult!(DType[]).makeFail();
}

ParseResult!DType parseFront(Token[] tokens) {
	// one of:

	// - primitive
	auto primResult = parsePrimitive(tokens);
	if (auto prim = primResult.isSuccess()) {
		// pass it through
		return primResult;
	} // no errors possible with parsePrimitive

	// - named thing
	auto idResult = parseIdentifier(tokens);
	if (auto id = idResult.isSuccess()) {

		// what about type arguments?
		auto argsResult = parseTypeArguments(id.etc);
		if (auto args = argsResult.isSuccess()) {
			auto dt = new NamedThing(id.thing, args.thing);
			return ParseResult!DType.makeSuccess(dt, args.loc, args.etc);

		} else if (auto err = argsResult.isError()) {
			// raise error (requires conversion)
			return reraise!DType(argsResult);
		}

		// else no type args - no worries
		auto dt = new NamedThing(id.thing);
		return ParseResult!DType.makeSuccess(dt, id.loc, id.etc);
	}

	// else we didn't find what we needed
	// (outside level will turn this into a true error)
	return ParseResult!DType.makeFail();
}

ParseResult!(FunctionArg[]) parseFunctionArgs(Token[] tokens) {
	auto contentResult = parseBetween(tokens, Token.Symbol.LeftParen, Token.Symbol.RightParen);
	if (auto content = contentResult.isSuccess()) {

		FunctionArg[] args;
		auto input = content.thing;

		while (input.length > 0) {

			// parse type (required)
			auto typeResult = parseType(input);
			if (auto type = typeResult.isSuccess()) {

				input = type.etc;

				// parse arg name (optional)
				string argName = null;

				auto nameResult = parseIdentifier(input);
				if (auto name = nameResult.isSuccess()) {
					argName = name.thing;
					input = name.etc;
				}

				args ~= FunctionArg(type.thing, argName);

				// parse comma or verify input end and return
				if (input.length > 0) {

					auto commaResult = parseSymbol(input, Token.Symbol.Comma);
					if (auto comma = commaResult.isSuccess()) {
						// excellent!
						input = comma.etc;
						continue;
					} // no errors possible for symbol parsing

					// else whoops
					return ParseResult!(FunctionArg[]).makeError("missing comma in function args list", input[0].loc); // input.length > 0 branch, so should be OK

				} else {
					// done reading all content - happy exit
					return ParseResult!(FunctionArg[]).makeSuccess(args, content.loc, content.etc); // content.etc = post-parens content!
				}

			} else if (auto err = typeResult.isError()) {
				// type parsing error, re-raise
				return reraise!(FunctionArg[])(typeResult);
			}

			// else non-existent - error because it's required
			return ParseResult!(FunctionArg[]).makeError("parseFunctionArgs: missing type", input[0].loc); // inside of input.length > 0 loop, so input[0].loc should be OK
		}
		// else ran out of input - but not in the normal way (needs to find end-of-input in the loop above)
		throw new Exception("parseFunctionArgs(): should be unreachable");

	} else if (auto err = contentResult.isError()) {
		// re-raise badness (missing right paren or whatever)
		reraise!(FunctionArg[])(contentResult);
	}

	// else no parens (outside will make this an error)
	return ParseResult!(FunctionArg[]).makeFail();
}

ParseResult!DType parseCallable(DType returnType, Location loc, Token[] tokens) {
	auto kwResult = parseOneOfKeywords(tokens, ["function", "delegate"]);
	if (auto kw = kwResult.isSuccess()) {

		// parse argument list (required!)
		auto argsResult = parseFunctionArgs(kw.etc);
		if (auto args = argsResult.isSuccess()) {

			// TODO: parse optional suffixes (pure/nothrow/etc)

			auto dt = new Callable(kw.thing, returnType, args.thing);
			return ParseResult!DType.makeSuccess(dt, args.loc, args.etc);

		} else if (auto err = argsResult.isError()) {
			reraise!DType(argsResult);
		} // else no args list found

		// ... so it's an error, because the keyword MUST be followed by a parameter list
		return ParseResult!DType.makeError("parseFuncOrDelegate: must be followed by args list", kw.loc);
	}
	// else didn't have a keyword, so not what we want
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
		// re-raise error (same type)
		return bracketedResult;
	}

	// - 'delegate' / 'function' + (args) + pure/nothrow/@safe/etc
	// current front is return type
	auto callableResult = parseCallable(front, loc, tokens);
	if (auto callable = callableResult.isSuccess()) {
		// need to recurse to see if there is more of a suffix (this callable might be part of an array, or a return type itself!)
		return parseTypeSuffix(callable.thing, callable.loc, callable.etc);
	} else if (auto err = callableResult.isError()) {
		// re-raise
		return callableResult;
	}

	// - none of the above - that's fine, means the type is finally complete (hopefully)
	return ParseResult!DType.makeSuccess(front, loc, tokens);
}

ParseResult!DType parseType(Token[] tokens, bool allowSuffix = true) { // can disable suffix parsing for single-argument (unparenthesized) type params
	if (tokens.length == 0) return ParseResult!DType.makeFail();

	// any leading stuff? (const/immutable/shared/etc)

	auto constResult = parseKeyword(tokens, "const");
	if (auto constSucc = constResult.isSuccess()) {
		// if parens, then recurse only on content
		// and then we still have to process the type suffix
		auto parenResult = parseBetween(constSucc.etc, Token.Symbol.LeftParen, Token.Symbol.RightParen);
		if (auto parenContent = parenResult.isSuccess()) {

			auto contentTypeResult = parseType(parenContent.thing);
			if (auto contentType = contentTypeResult.isSuccess()) {

				auto dt = new Const(contentType.thing, true);
				// that's now our 'front', now process suffix (after parens)
				return parseTypeSuffix(dt, parenContent.loc, parenContent.etc);

			} else if (auto err = contentTypeResult.isError()) {
				// re-raise
				return contentTypeResult;
			}

			// else failed to parse required content in const(...)
			return ParseResult!DType.makeError("failed to parse required content in const(...)", parenContent.loc);
		}

		// else =====

		// recurse on everything to the right of here: it's ALL content (nothing following)
		auto constContentResult = parseType(constSucc.etc);
		if (auto content = constContentResult.isSuccess()) {

			auto dt = new Const(content.thing, false);
			return ParseResult!DType.makeSuccess(dt, content.loc, content.etc);

		} else if (auto err = constContentResult.isError()) {
			// re-raise nested parse errors
			return constContentResult;
		}

		// else error, const content was required
		return ParseResult!DType.makeError("parseType: 'const' was not followed by a type", constSucc.loc);
	}

	// else no leading stuff:

	auto frontResult = parseFront(tokens);
	if (auto front = frontResult.isSuccess()) {
		// !!! but wait, this suffix handling stuff is broken in the case of arrays, which AFAIK should still work when used in a type parameter
		// eg Woot!int[]
		// is the space-separated stuff which fails ...
		// so do we need multiple potential suffix handlers?
		// one for arrays, and one for callables? and only callables are banned in no-suffix mode?
		if (allowSuffix) {
			// now pass to the suffix handler, which is recursive
			return parseTypeSuffix(front.thing, front.loc, front.etc);
		}
		// else
		return frontResult;
	} else if (auto err = frontResult.isError()) {
		// raise (same type)
		return frontResult;
	}

	return ParseResult!DType.makeFail();
}

// const const(const(int)[]) derp = [10];
// const int[][] derp2;
// const int[][string] yorp;
// const(int)[const(string)] argh;

// broken:
// Woot!int[] // disabled suffix handling for single type param will prevent [] from being handled ... I think

void main()
{
	auto tokens = tokenize("const int[string] function(const(float) x)");
	// foreach (t; tokens) {
	// 	writefln("token: %s", t);
	// }

	// writeln("====================");
	parseType(tokens).match!void(
		(auto success) {
			// writefln("DType: %s", success.thing);
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
			writefln("parse error: [%s] %s", error.message, error.loc);
		}
	);
}
