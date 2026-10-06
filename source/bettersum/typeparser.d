module bettersum.typeparser;

import bettersum.parsecommon;
import bettersum.tokenizer;
import bettersum.dtype;

SimpleResult!DType parsePrimitive(Token[] tokens) {
	if (auto prim = tryToken(tokens, 0, t => t.isPrimitive())) {
		return SimpleResult!DType.makeSuccess(new Primitive(*prim), tokens[0].loc, tokens[1..$]);
	}
	return SimpleResult!DType.makeFail();
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
		return makeError!DType(err.message, err.loc);
	}

	// else no worries
	return ParseResult!DType.makeFail();
}

struct TypeArgsResult {
	DType[] args;
	bool withParens;
}
ParseResult!TypeArgsResult parseTypeArguments(Token[] tokens) {

	// required !
	auto bangResult = parseSymbol(tokens, Token.Symbol.Bang);
	if (bangResult.isFail()) {
		// no type args ...
		return ParseResult!TypeArgsResult.makeFail();
	} // error not possible for parseSymbol

	// redefine for convenience
	tokens = bangResult.success.etc;

	// is it a single type?
	auto singleTypeResult = parseType(tokens, ParseTypeContext.SingleTypeParam);
	if (auto single = singleTypeResult.isSuccess()) {
		TypeArgsResult res = { [ single.thing ], false };
		return ParseResult!TypeArgsResult.makeSuccess(res, single.loc, single.etc);
	} else if (auto err = singleTypeResult.isError()) {
		// re-raise
		return makeError!TypeArgsResult(err.message, err.loc);
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
					return ParseResult!TypeArgsResult.makeError("missing comma in type args list", input[0].loc); // input.length > 0 branch, so should be OK

				} else {
					// done reading all content - happy exit
					TypeArgsResult res = { types, true };
					return ParseResult!TypeArgsResult.makeSuccess(res, type.loc, content.etc); // content.etc = post-parens content
				}

			} else if (auto err = typeResult.isError()) {
				// raise type-parsing error
				return makeError!TypeArgsResult(err.message, err.loc);
			}

			// else it's an error because we failed to parse a type (and didn't continue/exit first)
			return ParseResult!TypeArgsResult.makeError("parseTypeArguments: failed to parse a type", input[0].loc); // input.length > 0, so should be OK
		}
		throw new Exception("parseTypeArguments(): unreachable");

	} else if (auto err = parensResult.isError()) {
		// raise error (requires conversion)
		return makeError!TypeArgsResult(err.message, err.loc);
	}
	// no parens pair, fail gracefully
	return ParseResult!TypeArgsResult.makeFail();
}

ParseResult!DType parseFront(Token[] tokens) {
	// one of:

	// - primitive
	auto primResult = parsePrimitive(tokens);
	if (auto prim = primResult.isSuccess()) {
		// upgrade from SimpleResult to ParseResult
		return ParseResult!DType.makeSuccess(prim.thing, prim.loc, prim.etc);
	} // no errors possible with parsePrimitive

	// - named thing
	auto nameResult = parseQualifiedName(tokens);
	if (auto name = nameResult.isSuccess()) {

		// what about type arguments?
		auto argsResult = parseTypeArguments(name.etc);
		if (auto args = argsResult.isSuccess()) {

			auto dt = new NamedThing(name.thing, args.thing.args, args.thing.withParens);
			return ParseResult!DType.makeSuccess(dt, args.loc, args.etc);

		} else if (auto err = argsResult.isError()) {
			return makeError!DType(err.message, err.loc);
		}

		// else no type args - no worries
		auto dt = new NamedThing(name.thing);
		return ParseResult!DType.makeSuccess(dt, name.loc, name.etc);
	}

	// else we didn't find what we needed
	// (outside level will turn this into a true error)
	return ParseResult!DType.makeFail();
}

ParseResult!(FunctionArg[]) parseFunctionArgs(Token[] tokens) {
	auto contentResult = parseBetween(tokens, Token.Symbol.LeftParen, Token.Symbol.RightParen);
	if (auto content = contentResult.isSuccess()) {

		if (content.thing.length == 0) {
			// empty args, no worries
			return ParseResult!(FunctionArg[]).makeSuccess([], content.loc, content.etc);
		}

		FunctionArg[] args;
		auto input = content.thing;

		while (input.length > 0) {

			// parse type (required)
			auto typeResult = parseType(input, ParseTypeContext.FunctionArgs);
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
				return makeError!(FunctionArg[])(err.message, err.loc);
			}

			// else non-existent - error because it's required
			return ParseResult!(FunctionArg[]).makeError("parseFunctionArgs: missing type", input[0].loc); // inside of input.length > 0 loop, so input[0].loc should be OK
		}
		// else ran out of input - but not in the normal way (needs to find end-of-input in the loop above)
		throw new Exception("parseFunctionArgs(): should be unreachable");

	} else if (auto err = contentResult.isError()) {
		// re-raise badness (missing right paren or whatever)
		return makeError!(FunctionArg[])(err.message, err.loc);
	}

	// else no parens (outside will make this an error)
	return ParseResult!(FunctionArg[]).makeFail();
}

ParseResult!(FunctionAttr[]) parseFunctionAttrs(Token[] tokens) {
	FunctionAttr[] attrs;
	Location lastLoc;
	auto input = tokens;
	while (input.length > 0) {
		// one of:

		// @safe @nogc
		auto atResult = parseSymbol(input, Token.Symbol.At);
		if (auto at = atResult.isSuccess()) {
			auto kwResult = parseOneOfKeywords(at.etc, ["safe", "nogc"]);
			if (auto kw = kwResult.isSuccess()) {
				attrs ~= functionAttrFromString(kw.thing);
				input = kw.etc;
				lastLoc = kw.loc;
				continue;
			} else {
				// on fail: (no error possible)
				// after an @ requires either 'safe' or 'nogc' (or something else, which we'll add later)
				return ParseResult!(FunctionAttr[]).makeError("parseFunctionAttrs: failed to match function attr keyword after '@'", at.loc);
			}
		} // no error possible

		// pure nothrow
		auto otherResult = parseOneOfKeywords(input, ["pure", "nothrow"]);
		if (auto other = otherResult.isSuccess()) {
			attrs ~= functionAttrFromString(other.thing);
			input = other.etc;
			lastLoc = other.loc;
			continue;
		}
		// else failed to match any - we're done
		break;
	}
	if (attrs.length > 0) {
		return ParseResult!(FunctionAttr[]).makeSuccess(attrs, lastLoc, input);
	}
	return ParseResult!(FunctionAttr[]).makeFail();
}

ParseResult!DType parseCallable(DType returnType, Token[] tokens) {
	auto kwResult = parseOneOfKeywords(tokens, ["function", "delegate"]);
	if (auto kw = kwResult.isSuccess()) {

		// parse argument list (required!)
		auto argsResult = parseFunctionArgs(kw.etc);
		if (auto args = argsResult.isSuccess()) {

			// optional function attrs (pure, nothrow, etc)
			auto attrsResult = parseFunctionAttrs(args.etc);
			if (auto attrs = attrsResult.isSuccess()) {
				auto dt = new Callable(kw.thing, returnType, args.thing, attrs.thing);
				return ParseResult!DType.makeSuccess(dt, attrs.loc, attrs.etc);
			}

			// else
			auto dt = new Callable(kw.thing, returnType, args.thing, []);
			return ParseResult!DType.makeSuccess(dt, args.loc, args.etc);

		} else if (auto err = argsResult.isError()) {
			return makeError!DType(err.message, err.loc);
		} // else no args list found

		// ... so it's an error, because the keyword MUST be followed by a parameter list
		return ParseResult!DType.makeError("parseFuncOrDelegate: must be followed by args list", kw.loc);
	}
	// else didn't have a keyword, so not what we want
	return ParseResult!DType.makeFail();
}

enum ParseTypeContext {
	Normal,
	SingleTypeParam,
	FunctionArgs // 'ref' allowed
}

ParseResult!DType parseTypeSuffix(DType front, Location loc, Token[] tokens, ParseTypeContext context) {
	// one of:

	// - pointer suffix
	auto starResult = parseSymbol(tokens, Token.Symbol.Star);
	if (auto star = starResult.isSuccess()) {
		// OK, keep going
		auto dt = new Pointer(front);
		return parseTypeSuffix(dt, star.loc, star.etc, context);
	}

	// - array suffix (recurse on content, depending)
	auto bracketedResult = parseBracketed(front, tokens);
	if (auto bracketed = bracketedResult.isSuccess()) {
		// need to recurse to see if there is more of a suffix
		return parseTypeSuffix(bracketed.thing, bracketed.loc, bracketed.etc, context);

	} else if (auto err = bracketedResult.isError()) {
		// re-raise error (same type)
		return bracketedResult;
	}

	// - dot suffix (named thing contained by front type)
	auto dotResult = parseSymbol(tokens, Token.Symbol.Dot);
	if (auto dot = dotResult.isSuccess()) {
		auto nestedResult = parseType(dot.etc, context); // do we need a new context for nested stuff?
		if (auto nested = nestedResult.isSuccess()) {

			// front + [front + [front + nested]]
			auto dt = new Nested(front, nested.thing);
			return parseTypeSuffix(dt, nested.loc, nested.etc, context);

		} else if (auto err = nestedResult.isError()) {
			return makeError!DType(err.message, err.loc);
		}
		// if dot existed, had to be followed with type
		return ParseResult!DType.makeError("dot (.) not followed by type", dot.loc);
	}

	// - callable, in some contexts:
	if (context != ParseTypeContext.SingleTypeParam) { // can't process callables without parens in this context, because that's definitely not wanted
		// current front is return type
		auto callableResult = parseCallable(front, tokens);
		if (auto callable = callableResult.isSuccess()) {
			// need to recurse to see if there is more of a suffix (this callable might be part of an array, or a return type itself!)
			return parseTypeSuffix(callable.thing, callable.loc, callable.etc, context);
		} else if (auto err = callableResult.isError()) {
			// re-raise
			return callableResult;
		}
	}

	// - none of the above - that's fine, means the type is finally complete (hopefully)
	return ParseResult!DType.makeSuccess(front, loc, tokens);
}

ParseResult!DType parseType(Token[] tokens, ParseTypeContext context = ParseTypeContext.Normal) {
	if (tokens.length == 0) return ParseResult!DType.makeFail();

	// backticked type literal?
	if (auto lit = tryToken(tokens, 0, t => t.isBackticked())) {
		return ParseResult!DType.makeSuccess(new TypeLiteral(*lit), tokens[0].loc, tokens[1..$]);
	}

	// typeof(`...`) expression (note the backticks)
	auto typeofResult = parseKeyword(tokens, "typeof");
	if (auto typeof_ = typeofResult.isSuccess()) {
		auto contentResult = parseBetween(typeof_.etc, Token.Symbol.LeftParen, Token.Symbol.RightParen);
		if (auto content = contentResult.isSuccess()) {

			if (content.thing.length == 0) {
				return ParseResult!DType.makeError("typeof() is empty", content.loc);
			}

			// we can't do full D expression parsing, so the inner content needs to be a backticked literal
			if (auto bt = tryToken(content.thing, 0, t => t.isBackticked)) {
				return ParseResult!DType.makeSuccess(new TypeOf(*bt), content.loc, content.etc);
			}

			// else, error - we could try joining together all the tokens with no spaces, but I don't think that's a good policy
			return ParseResult!DType.makeError("typeof() content must be backticked D expression", content.loc);
		}
		 else if (auto err = contentResult.isError()) {
			return makeError!DType(err.message, err.loc);
		}

		// else 'typeof' without paren content - also an error
		return ParseResult!DType.makeError("'typeof' with content", typeof_.loc);
	}

	// 'ref' (if allowed in this context)
	auto refResult = parseKeyword(tokens, "ref");
	if (auto ref_ = refResult.isSuccess()) {
		if (context != ParseTypeContext.FunctionArgs) {
			// whoops, not allowed
			return ParseResult!DType.makeError("'ref' only usable in function/delegate arg types'", ref_.loc);
		}
		// proceed as normal
		auto refContent = parseType(ref_.etc, context);
		if (auto content = refContent.isSuccess()) {
			if (cast(Ref)content.thing !is null) {
				return ParseResult!DType.makeError("can't have 'ref ref' type!", content.loc);
			}
			auto dt = new Ref(content.thing);
			return ParseResult!DType.makeSuccess(dt, content.loc, content.etc);
		} else if (auto err = refContent.isError()) {
			// raise error
			return refContent;
		}
		// else no type was parsed - error, because required
		return ParseResult!DType.makeError("parsing 'ref' content: no subsequent type", ref_.loc);
	}

	// type qualifiers:
	auto qualResult = parseOneOfKeywords(tokens, ["const", "immutable", "shared"]);
	if (auto qualifier = qualResult.isSuccess()) {

		// if parens, then recurse only on content
		// and then we still have to process the type suffix
		auto parenResult = parseBetween(qualifier.etc, Token.Symbol.LeftParen, Token.Symbol.RightParen);
		if (auto parenContent = parenResult.isSuccess()) {

			auto contentTypeResult = parseType(parenContent.thing);
			if (auto contentType = contentTypeResult.isSuccess()) {

				auto dt = new Qualified(qualifier.thing, contentType.thing, true);
				// that's now our 'front', now process suffix (after parens)
				return parseTypeSuffix(dt, parenContent.loc, parenContent.etc, context);

			} else if (auto err = contentTypeResult.isError()) {
				// re-raise
				return contentTypeResult;
			}

			// else failed to parse required content in const(...)
			return ParseResult!DType.makeError("failed to parse required content in const(...)", parenContent.loc);
		}

		// else =====

		// can't process unscoped const in a type parameter context
		if (context != ParseTypeContext.SingleTypeParam) {

			// recurse on everything to the right of here: it's ALL content (nothing following)
			auto constContentResult = parseType(qualifier.etc, context);
			if (auto content = constContentResult.isSuccess()) {

				auto dt = new Qualified(qualifier.thing, content.thing, false); // scoped = false
				return ParseResult!DType.makeSuccess(dt, content.loc, content.etc);

			} else if (auto err = constContentResult.isError()) {
				// re-raise nested parse errors
				return constContentResult;
			}

		} else {
			return ParseResult!DType.makeError("parseType: can't have unscoped `const` in the context of a type parameter", qualifier.loc);
		}

		// else error, const content was required but not present
		return ParseResult!DType.makeError("parseType: 'const' was not followed by a type", qualifier.loc);
	}

	// else no leading stuff:

	auto frontResult = parseFront(tokens);
	if (auto front = frontResult.isSuccess()) {
		// now pass to the suffix handler, which is recursive
		return parseTypeSuffix(front.thing, front.loc, front.etc, context);
	} else if (auto err = frontResult.isError()) {
		// raise (same type)
		return frontResult;
	}

	return ParseResult!DType.makeFail();
}

unittest {
	import std.string: replace;

	bool verifyParse(string input) {
		auto tokens = tokenize(input);
		return parseType(tokens).match!bool(
			(auto success) {
				auto compareWith = input.replace("`", ""); // strip out backticks for the purpose of comparison
				auto rendered = success.thing.renderToString();
				return rendered == compareWith;
			},
			(auto fail) {
				return false; // failed to parse type, no over errors
			},
			(auto error) {
				return false; // active error
			}
		);
	}

	assert(verifyParse(q{int}));
	assert(verifyParse(q{int[]}));
	assert(verifyParse(q{ulong[string]}));
	assert(verifyParse(q{Woot!(void function(ref const int[]))[string]}));
	assert(verifyParse(q{const shared string[int]*[void delegate(Woot!int x) nothrow @safe]}));
	assert(verifyParse(q{Woot!Something[]}));
	assert(verifyParse(q{Woot!(Something[])}));

    assert(verifyParse(q{string[10_000]}));
    assert(verifyParse(q{int}));
    assert(verifyParse(q{string}));
    assert(verifyParse(q{uint}));
    assert(verifyParse(q{long}));
    assert(verifyParse(q{double}));
    assert(verifyParse(q{char}));

    assert(verifyParse(q{int*}));
    assert(verifyParse(q{int**}));
    assert(verifyParse(q{int[]}));
    assert(verifyParse(q{int[10]}));
    assert(verifyParse(q{int[10][20]}));
    assert(verifyParse(q{int[string]}));

    assert(verifyParse(q{const(int)}));
    assert(verifyParse(q{immutable(int)}));
    assert(verifyParse(q{shared(int)}));
    assert(verifyParse(q{const(int*)}));
    assert(verifyParse(q{immutable(int[])}));
    assert(verifyParse(q{const(int[int])}));
    assert(verifyParse(q{shared(const(int*))}));
    assert(verifyParse(q{const(immutable(int*))}));

    assert(verifyParse(q{int function()}));
    assert(verifyParse(q{int function(int)}));
    assert(verifyParse(q{int function(int, string)}));
    assert(verifyParse(q{int delegate(int)}));
    assert(verifyParse(q{void function(int, double)}));
    assert(verifyParse(q{int* function(int*)}));
    assert(verifyParse(q{int[] function(int[int])}));
    assert(verifyParse(q{int function(int function(int))}));

    assert(verifyParse(q{int**[]}));
    assert(verifyParse(q{int[][10]}));
    assert(verifyParse(q{int[10][]}));
    assert(verifyParse(q{int[int[]]}));
    assert(verifyParse(q{int[][int]}));
    assert(verifyParse(q{const(int*)[]}));
    assert(verifyParse(q{const(int[]*)}));
    assert(verifyParse(q{immutable(int[int])*}));
    assert(verifyParse(q{shared(const(int**[]))}));
    assert(verifyParse(q{int function(int*)[]}));
    assert(verifyParse(q{int[] function(int[int])}));
    assert(verifyParse(q{int function(int function(int*), int[])}));

    assert(verifyParse(q{const(int*[])[10]}));
    assert(verifyParse(q{immutable(int[int[]])*}));
    assert(verifyParse(q{int function(int function(int)[], int[int]*)}));
    assert(verifyParse(q{const(int function(int*)[])}));
    assert(verifyParse(q{int[] function(int[] function(int*))}));
    assert(verifyParse(q{shared(const(immutable(int**[])))[10]}));
    assert(verifyParse(q{int function(int function(int function(int)))}));
    assert(verifyParse(q{int[int[]][10]}));
    assert(verifyParse(q{const(int function(int[int])*)}));
    assert(verifyParse(q{int function(const(int*)[], immutable(int[int])*)[]}));

    assert(verifyParse(q{int[string]}));
    assert(verifyParse(q{const(int[])}));
    assert(verifyParse(q{const(const int[])}));
    assert(verifyParse(q{foo!(int,string)[]}));
    assert(verifyParse(q{const(int delegate(int) pure nothrow[])}));
    assert(verifyParse(q{typeof(`foo!(T).bar`)}));
    assert(verifyParse(q{int function(int, int) pure nothrow @safe}));
    assert(verifyParse(q{const(thing1.thing2.Woot!int.Subwoot)[]}));
}
