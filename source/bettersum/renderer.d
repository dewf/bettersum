module bettersum.renderer;

import bettersum.parser;
import bettersum.dtype;
import bettersum.options;

import std.array : appender, join;
import std.ascii: toUpper, toLower;
import std.algorithm: map;
import std.format: format;

string upperFirst(string s) {
	if (!s || s.length == 0) return s;
	return toUpper(s[0]) ~ s[1 .. $];
}

string lowerFirst(string s) {
	if (!s || s.length == 0) return s;
	return toLower(s[0]) ~ s[1 .. $];
}

string sumTypeName(ref SumTypeDef def, ref SumtypeOptions options) {
	return def.name.upperFirst();
}

string caseSpecName(ref Case c, ref SumtypeOptions options) {
	return c.name;
}

string caseContentType(ref Case c, ref SumtypeOptions options) {
	return c.payload.match!string(
		(auto nameOnly) => throw new Exception("caseContentType() called with 'NameOnly' payload"),
		(auto singleType) => singleType.renderToString(),
		(auto namedArgs) => "_" ~ c.name.upperFirst() // struct name
	);
}

string caseFieldName(ref Case c, ref SumtypeOptions options) {
	return c.name.lowerFirst();
}

string caseTagName(ref Case c, ref SumtypeOptions options) {
	return c.name.upperFirst();
}

string caseIsName(ref Case c, ref SumtypeOptions options) {
	return "is" ~ caseSpecName(c, options);
}

string caseGetterName(ref Case c, ref SumtypeOptions options) {
	return "get" ~ caseSpecName(c, options);
}

string caseFuncName(ref Case c, ref SumtypeOptions options) {
	return c.name.lowerFirst();
}

string renderSumType(ref SumTypeDef def, ref SumtypeOptions options)
{
	auto output = appender!string;

	if (def.typeParams.length > 0) {
		auto joined = def.typeParams.join(", ");
		output ~= format("struct %s(%s) {\n", sumTypeName(def, options), joined);
	} else {
		output ~= format("struct %s {\n", sumTypeName(def, options));
	}

	output ~= "    import std.exception: enforce;\n";
	output ~= "private:\n";

	// case type defs (now private)
	foreach (c; def.cases) {
		if (c.payload.isNameOnly()) {
			// nothing to output, tag-only
			output ~= format("    // %s: name only\n", caseSpecName(c, options));
		} else if (auto single = c.payload.isSingleType()) {
			// nothing to output, tag + string field in Content
			output ~= format("    // %s: name + single type, no fields\n", caseSpecName(c, options));
		} else if (auto namedArgs = c.payload.isNamedArgs()) {
			auto fields = (*namedArgs).map!(arg => format("%s %s;", arg.type.renderToString(), arg.name)).join(" ");
			output ~= format("    struct %s { %s }\n", caseContentType(c, options), fields);
		}
	}
	output ~= "\n";

	output ~= "    union Content {\n";
	foreach (c; def.cases) {
		output ~=
			c.payload.match!string(
				(auto nameOnly) => format("        // %s: name only\n", caseFieldName(c, options)),
				(auto singleType) => format("        %s %s;\n", singleType.renderToString(), caseFieldName(c, options)),
				(auto namedArgs) => format("        %s %s;\n", caseContentType(c, options), caseFieldName(c, options))
			);
	}
	output ~= "    }\n"; // end union Content

	output ~= "    Tag _tag;\n";
	output ~= "    Content content;\n";
	output ~= "public:\n";

	auto tagNames = def.cases.map!(c => caseTagName(c, options)).join(", ");
	output ~= format("    enum Tag { %s }\n", tagNames);

	output ~= "    Tag tag() => _tag;\n";

	// TODO: remove if we don't keep assoc array match
	// output ~= "    enum TagAny = cast(Tag) 1024;\n";

	// output ~= "\n";

	// ctor/getters
	foreach (c; def.cases) {
		// if (i != 0) output ~= "\n";
		output ~= "\n";

		output ~= format("    // %s ==================================\n", caseSpecName(c, options));
		// ctor
		auto ctorParams =
			c.payload.match!string(
				(auto nameOnly) => "",
				(auto singleType) => format("%s value", singleType.renderToString()),
				(auto namedArgs) => namedArgs.map!(arg => format("%s %s", arg.type.renderToString(), arg.name)).join(", ")
			);
		output ~= format("    static %s %s(%s) {\n", sumTypeName(def, options), caseSpecName(c, options), ctorParams);

		if (c.payload.isNameOnly()) {
			output ~= "        Content c;\n";
		} else if (auto singleType = c.payload.isSingleType()) {
			output ~= format("        Content c = { %s: value };\n", caseFieldName(c, options));
		} else if (auto namedArgs = c.payload.isNamedArgs()) {
			auto fieldNames = (*namedArgs).map!(arg => arg.name).join(", ");
			output ~= format("        Content c = { %s: %s(%s) };\n", caseFieldName(c, options), caseContentType(c, options), fieldNames);
		}

		output ~= format("        return %s(Tag.%s, c);\n", sumTypeName(def, options), caseTagName(c, options));
		output ~= "    }\n";

		final switch (c.payload.tag()) with (CasePayload) {
			case Tag.NameOnly:
				// "is" checker
				output ~= format("    bool %s() => _tag == Tag.%s;\n", caseIsName(c, options), caseTagName(c, options));
				// no getter
				output ~= "    // name-only, no getter\n";
				break;
			case Tag.SingleType, Tag.NamedArgs:
				// "is" checker+getter
				output ~= format("    %s* %s() => _tag == Tag.%s ? &content.%s : null;\n", caseContentType(c, options), caseIsName(c, options), caseTagName(c, options), caseFieldName(c, options));
				// force-getter
				output ~= format("    ref %s %s() {\n", caseContentType(c, options), caseGetterName(c, options));
				output ~= format("        enforce(_tag == Tag.%s, \"%s.%s(): tag doesn't match\");\n", caseTagName(c, options), sumTypeName(def, options), caseGetterName(c, options));
				output ~= format("        return content.%s;\n", caseFieldName(c, options));
				output ~= "    }\n";
				break;
		}
	}

	// multi-test
	output ~= "\n";
	output ~= "    // multi-test ==========================\n";
	output ~= q"EOF
    bool isOneOf(Tag[] tags ...) {
        foreach (t; tags) {
            if (t == _tag) return true;
        }
        return false;
    }
    bool isOneOf(string caseNames)() {
        import std.string: split;
        import std.algorithm : canFind;
        static immutable inputCases = caseNames.split(", ");
        static assert(inputCases.length > 0, "isOneOf: no case names provided");
        final switch (_tag) {
EOF";
	foreach (c; def.cases) {
		output ~= format("            case Tag.%s:\n", caseTagName(c, options));
		output ~= format("                return inputCases.canFind(\"%s\");\n", caseSpecName(c, options));
	}
	output ~= "        }\n"; // end final switch
	output ~= "    }\n"; // end isOneOf()

	// exhaustive check
	output ~= "\n";
	output ~= q"EOF
    // exhaustive check =======================
    // place in a static assert so you can catch all the places that need to be changed, when you add a new case
    static bool isExhaustive(string caseNames)
    {
        import std.string: split;
        import std.algorithm.sorting: sort;
        auto inputCases = caseNames.split(", ").sort();
EOF";
	auto caseNames = def.cases.map!(c => format("\"%s\"", caseSpecName(c, options))).join(", ");
	output ~= format("        auto checkAgainst = [%s].sort();\n", caseNames);
	output ~= "        return inputCases == checkAgainst;\n";
	output ~= "    }\n"; // end isExhaustive

	// simple match expression
	output ~= "\n";
	output ~= "    // basic match expression =====================\n";
	output ~= "    struct _NameOnly {}\n";
	output ~= "    _MatchResult match(_MatchResult)(\n";
	auto delegateArgs =
		def.cases.map!(c =>
			c.payload.match!string(
				(auto nameOnly) => format("        _MatchResult delegate(ref _NameOnly) %sFunc", caseFuncName(c, options)),
				(auto singleType) => format("        _MatchResult delegate(ref %s) %sFunc", caseContentType(c, options), caseFuncName(c, options)),
				(auto namedArgs) => format("        _MatchResult delegate(ref %s) %sFunc", caseContentType(c, options), caseFuncName(c, options))
			)).join(",\n");
	output ~= format("%s)\n", delegateArgs);
	output ~= "    {\n";
	output ~= "        _NameOnly fakeArg;\n";
	output ~= "        final switch(_tag) {\n";
	foreach (c; def.cases) {
		output ~= format("            case Tag.%s:\n", caseTagName(c, options));
		final switch (c.payload.tag()) with (CasePayload) {
			case Tag.NameOnly:
				output ~= format("                return %sFunc(fakeArg);\n", caseFuncName(c, options));
				break;
			case Tag.SingleType, Tag.NamedArgs:
				output ~= format("                return %sFunc(content.%s);\n", caseFuncName(c, options), caseFieldName(c, options));
				break;
		}
	}
	output ~= "        }\n"; // end final switch
	output ~= "    }\n"; // end basic match expression

	// visitor-style match expression
	output ~= "\n";
	output ~= "    // visitor-style match expression =============\n";
	output ~= "    abstract class Matcher(_MatchResult) {\n";
	foreach (c; def.cases) {
		auto args =
			c.payload.match!string(
				(auto nameOnly) => "",
				(auto singleType) => format("%s value", singleType.renderToString()),
				(auto namedArgs) => namedArgs.map!(arg => format("%s %s", arg.type.renderToString(), arg.name)).join(", ")
			);
		output ~= format("        _MatchResult %s(%s) => any();\n", caseFuncName(c, options), args);
	}
	output ~= "        _MatchResult any() {\n";
	output ~= format("            throw new Exception(\"%s.Matcher.any() called, but not implemented\");\n", sumTypeName(def, options));
	output ~= "        }\n";
	output ~= "    }\n"; // end Matcher base class

	// visit method
	output ~= "\n";
	output ~= "    _MatchResult match(_MatchResult)(Matcher!_MatchResult matcher) {\n";
	output ~= "        final switch(_tag) {\n";
	foreach (c; def.cases) {
		output ~= format("            case Tag.%s:\n", caseTagName(c, options));
		auto args =
			c.payload.match!string(
				(auto nameOnly) => "",
				(auto singleType) => format("content.%s", caseFieldName(c, options)),
				(auto namedArgs) => namedArgs.map!(arg => format("content.%s.%s", caseFieldName(c, options), arg.name)).join(", ")
			);
		output ~= format("                return matcher.%s(%s);\n", caseFuncName(c, options), args);
	}
	output ~= "        }\n"; // end final switch
	output ~= "    }\n"; // end match()

	output ~= "}\n"; // end struct

	return output[];
}
