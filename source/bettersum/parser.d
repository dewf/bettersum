module bettersum.parser;

import bettersum.tokenizer;
import bettersum.parsecommon;
import bettersum.typeparser;
import bettersum.dtype;

// TODO: remove
import stonesoup.sumtype: sumtype;

enum CommaOrEnd {
	Comma,
	End
}

SimpleResult!CommaOrEnd parseCommaOrEnd(Token[] input, Location loc) {
	if (input.length == 0) {
		return SimpleResult!CommaOrEnd.makeSuccess(CommaOrEnd.End, loc, input);
	}
	if (auto sym = tryToken(input, 0, t => t.isSymbol())) {
		return SimpleResult!CommaOrEnd.makeSuccess(CommaOrEnd.Comma, input[0].loc, input[1..$]);
	}
	return SimpleResult!CommaOrEnd.makeFail();
}

struct CaseArg {
	DType type;
	string name; // optional
}

ParseResult!(CaseArg[]) parseCaseArgs(Token[] input, Location loc) {
	CaseArg[] params;
	CaseArg current;
	Location lastLoc = loc;

	while (input.length > 0) {

		// type required on every iteration:
		auto typeResult = parseType(input);
		if (auto type = typeResult.isSuccess()) {

			current.type = type.thing;
			input = type.etc;
			lastLoc = type.loc;

			// optional name follows
			auto nameResult = parseIdentifier(input);
			if (auto name = nameResult.isSuccess()) {
				// cool, we have a name
				current.name = name.thing;
				input = name.etc;
				lastLoc = name.loc;
			} // no error possible

			params ~= current;

			// no name, no worries - check for comma and continue
			auto commaOrEndResult = parseCommaOrEnd(input, lastLoc);
			if (auto commaOrEnd = commaOrEndResult.isSuccess()) {
				// good to go another cycle (or might terminate if at end of input)
				input = commaOrEnd.etc;
				lastLoc = commaOrEnd.loc;
				continue;

			} else {
				return ParseResult!(CaseArg[]).makeError("expected comma/end-of-input", lastLoc);
			}

		} else if (auto err = typeResult.isError()) {
			return reraise!(CaseArg[])(err.message, err.loc);
		}

		// iteration failed to parse a type where expected - this is an error
		return ParseResult!(CaseArg[]).makeError("type expected, not found", input[0].loc); // input.length > 0, should be OK
	}

	if (params.length >= 0) {
		// we allow 0-length params, just to be nice
		return ParseResult!(CaseArg[]).makeSuccess(params, lastLoc, input);
	}
	// should be unreachable
	return ParseResult!(CaseArg[]).makeError("parseCaseArgs: should be unreachable", lastLoc);
}

mixin(sumtype(q{
CasePayload {
	NameOnly,
	SingleType(`DType`),
	NamedArgs(`CaseArg[]`)
}
}));

struct Case {
	string name;
	CasePayload payload;
}

bool allArgsComplete(CaseArg[] args) {
	import std.algorithm.searching: all;
	return args.all!(arg => arg.type !is null && arg.name !is null);
}

ParseResult!Case parseCase(Token[] input) {
	auto nameResult = parseIdentifier(input);
	if (auto name = nameResult.isSuccess()) {

		// does it have params and content?
		auto contentResult = parseBetween(name.etc, Token.Symbol.LeftParen, Token.Symbol.RightParen);
		if (auto content = contentResult.isSuccess()) {

			// parse arg list
			auto argsResult = parseCaseArgs(content.thing, content.loc);
			if (auto args = argsResult.isSuccess()) {
				// check and see which kind:

				// - no args (empty parens)
				if (args.thing.length == 0) {
					auto c = Case(name.thing, CasePayload.makeNameOnly());
					return ParseResult!Case.makeSuccess(c, args.loc, content.etc); // content.etc is furthest reached
				}
				// - single type-only arg
				else if (args.thing.length == 1 && args.thing[0].name is null) {
					auto payload = CasePayload.makeSingleType(args.thing[0].type);
					auto c = Case(name.thing, payload);
					return ParseResult!Case.makeSuccess(c, args.loc, content.etc);
				}
				// - one or more type+name args
				else if (allArgsComplete(args.thing)) {
					auto payload = CasePayload.makeNamedArgs(args.thing);
					auto c = Case(name.thing, payload);
					return ParseResult!Case.makeSuccess(c, args.loc, content.etc);
				}
				// - [anything else is error - we don't allow unnamed type tuples, for example]
				else {
					return ParseResult!Case.makeError("tuple-style (multiple type-only) args not allowed", args.loc);
				}

			} else if (auto err = argsResult.isError()) {
				return reraise!Case(err.message, err.loc);
			}

			// should be unreachable, but ...
			return ParseResult!Case.makeError("parseCase: unknown case args parse issue - please report!", content.loc);

		} else if (auto err = contentResult.isError()) {
			return reraise!Case(err.message, err.loc);
		}

		// else nope, just a name
		auto c = Case(name.thing, CasePayload.makeNameOnly());
		return ParseResult!Case.makeSuccess(c, name.loc, name.etc);
	}
	// else no identifier - it's not a case
	return ParseResult!Case.makeFail();
}

ParseResult!(Case[]) parseCases(Token[] input, Location loc) {
	Case[] cases;
	Location lastLoc = loc;

	while (input.length > 0) {
		auto caseResult = parseCase(input);
		if (auto case_ = caseResult.isSuccess()) {
			cases ~= case_.thing;
			input = case_.etc;
			lastLoc = case_.loc;

			auto commaOrEndResult = parseCommaOrEnd(input, case_.loc);
			if (auto commaOrEnd = commaOrEndResult.isSuccess()) {
				input = commaOrEnd.etc;
				lastLoc = commaOrEnd.loc;
				continue;
			} else {
				// missing required comma/end
				return ParseResult!(Case[]).makeError("missing comma/block end after case", case_.loc);
			}
		} else if (auto err = caseResult.isError()) {
			reraise!(Case[])(err.message, err.loc);
		}
		// else failed to parse a case - fall through to below (kinda seems like it should be an error, though)
	}
	if (cases.length > 0) {
		return ParseResult!(Case[]).makeSuccess(cases, lastLoc, input);
	}
	// else simple fail
	return ParseResult!(Case[]).makeFail();
}

struct SumTypeDef {
	string name;
	string[] typeParams;
	Case[] cases;
}

ParseResult!(string[]) parseTypeParams(Token[] input, Location loc) {
	string[] result;
	Location lastLoc = loc;
	while (input.length > 0) {
		auto idResult = parseIdentifier(input);
		if (auto id = idResult.isSuccess()) {
			result ~= id.thing;
			input = id.etc;
			lastLoc = id.loc;

			auto commaOrEndResult = parseCommaOrEnd(input, id.loc);
			if (auto commaOrEnd = commaOrEndResult.isSuccess()) {
				input = commaOrEnd.etc;
				lastLoc = commaOrEnd.loc;
				continue;
			} else {
				return ParseResult!(string[]).makeError("expected comma (or end of block) after type param", lastLoc);
			}
		} // no error to handle
		// failed to parse required identifier
		return ParseResult!(string[]).makeError("identifier expected", lastLoc);
	}
	if (result.length > 0) {
		return ParseResult!(string[]).makeSuccess(result, lastLoc, input);
	}
	return ParseResult!(string[]).makeFail();
}

ParseResult!SumTypeDef parseSumType(string definition) {
	auto tokenResult = tokenize(definition);
	if (auto err = tokenResult.isError()) {
		// re-raise
		return ParseResult!SumTypeDef.makeError(err.message, err.loc);
	}
	// else OK
	auto tokens = tokenResult.success();
	Location lastLoc;

	auto nameResult = parseIdentifier(tokens);
	if (auto name = nameResult.isSuccess()) {
		auto input = name.etc;
		lastLoc = name.loc;

		// optional type parameters
		string[] typeParams;
		auto parensContentResult = parseBetween(input, Token.Symbol.LeftParen, Token.Symbol.RightParen);
		if (auto parensContent = parensContentResult.isSuccess()) {
			auto tpStringsResult = parseTypeParams(parensContent.thing, parensContent.loc);
			if (auto tpStrings = tpStringsResult.isSuccess()) {
				typeParams = tpStrings.thing;
				input = parensContent.etc; // outside of right paren
				lastLoc = tpStrings.loc; // hmmm
			}
		}

		// actual case content
		auto bracesContentResult = parseBetween(input, Token.Symbol.LeftBrace, Token.Symbol.RightBrace);
		if (auto bracesContent = bracesContentResult.isSuccess()) {

			auto casesResult = parseCases(bracesContent.thing, bracesContent.loc);
			if (auto cases = casesResult.isSuccess()) {
				auto def = SumTypeDef(name.thing, typeParams, cases.thing);
				return ParseResult!SumTypeDef.makeSuccess(def, cases.loc, bracesContent.etc); // beyond right brace
			}

		} else if (auto err = bracesContentResult.isError()) {
			reraise!SumTypeDef(err.message, err.loc);
		}
		// else failed to parse braces content, which is required
		return ParseResult!SumTypeDef.makeError("missing braced { cases } for sumtype", lastLoc);
	}
	return ParseResult!SumTypeDef.makeError("missing sumtype name", lastLoc);
}
