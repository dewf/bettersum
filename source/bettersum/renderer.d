module bettersum.renderer;

import bettersum.parser;
import bettersum.dtype;
import bettersum.options;
import bettersum.util: getOrDefault;

import std.array : appender, join;
import std.ascii: toUpper, toLower;
import std.algorithm: map;

string upperFirst(string s) {
	if (!s || s.length == 0) return s;
	return toUpper(s[0]) ~ s[1 .. $];
}

string lowerFirst(string s) {
	if (!s || s.length == 0) return s;
	return toLower(s[0]) ~ s[1 .. $];
}

string sumTypeName(ref SumTypeDef def) {
	return def.name;
}

string caseSpecName(ref Case c) {
	return c.name;
}

string caseContentType(ref Case c, NamingConvention nc) {
	return c.payload.match!string(
		(auto nameOnly) => throw new Exception("caseContentType() called with 'NameOnly' payload"),
		(auto singleType) => singleType.renderToString(),
		(auto namedArgs) => "_" ~ c.name // struct name
	);
}

string caseFieldName(ref Case c, NamingConvention nc) {
	return c.name.lowerFirst();
}

string caseTagName(ref Case c, NamingConvention nc) {
	return c.name;
}

string caseIsName(ref Case c, NamingConvention nc) {
	final switch (nc) with (NamingConvention) {
		case PascalCase:
			return "is" ~ caseSpecName(c);
		case SnakeCase:
			return "is_" ~ caseSpecName(c);
	}
}

string caseGetterName(ref Case c, NamingConvention nc) {
	final switch (nc) with (NamingConvention) {
		case PascalCase:
			return "get" ~ caseSpecName(c);
		case SnakeCase:
			return "get_" ~ caseSpecName(c);
	}
}

string caseFuncName(ref Case c, NamingConvention nc) {
	return c.name.lowerFirst();
}

string renderSumType(ref SumTypeDef def, ref SumtypeOptions options)
{
	auto namingConvention = options.namingConvention.getOrDefault(NamingConvention.PascalCase);
	auto output = appender!string;

	if (def.typeParams.length > 0) {
		auto joined = def.typeParams.join(", ");
		output ~= "struct " ~ sumTypeName(def) ~ "(" ~ joined ~ ") {\n";
	} else {
		output ~= "struct " ~ sumTypeName(def) ~ " {\n";
	}

	output ~= "    import std.exception: enforce;\n";
	output ~= "private:\n";

	// case type defs (now private)
	foreach (c; def.cases) {
		if (c.payload.isNameOnly()) {
			// nothing to output, tag-only
			output ~= "    // " ~ caseSpecName(c) ~ ": name only\n";

		} else if (auto single = c.payload.isSingleType()) {
			// nothing to output, tag + string field in Content
			output ~= "    // " ~ caseSpecName(c) ~ ": name + single type, no fields\n";

		} else if (auto namedArgs = c.payload.isNamedArgs()) {
			auto fields = (*namedArgs).map!(arg => arg.type.renderToString() ~ " " ~ arg.name ~ ";").join(" ");
			output ~= "    struct " ~ caseContentType(c, namingConvention) ~ " { " ~ fields ~ " }\n";
		}
	}
	output ~= "\n";

	output ~= "    union Content {\n";
	foreach (c; def.cases) {
		output ~=
			c.payload.match!string(
				(auto nameOnly) => "        // " ~ caseFieldName(c, namingConvention) ~ ": name only\n",
				(auto singleType) => "        " ~ singleType.renderToString() ~ " " ~ caseFieldName(c, namingConvention) ~ ";\n",
				(auto namedArgs) => "        " ~ caseContentType(c, namingConvention) ~ " " ~ caseFieldName(c, namingConvention) ~ ";\n"
			);
	}
	output ~= "    }\n"; // end union Content

	output ~= "    Tag _tag;\n";
	output ~= "    Content content;\n";
	output ~= "public:\n";

	auto tagNames = def.cases.map!(c => caseTagName(c, namingConvention)).join(", ");
	output ~= "    enum Tag { " ~ tagNames ~ " }\n";
	output ~= "    Tag tag() => _tag;\n";

	// output ~= "\n";

	// ctor/getters
	foreach (c; def.cases) {
		// if (i != 0) output ~= "\n";
		output ~= "\n";

		output ~= "    // " ~ caseSpecName(c) ~ " ==================================\n";

		// ctor
		auto ctorParams =
			c.payload.match!string(
				(auto nameOnly) => "",
				(auto singleType) => singleType.renderToString() ~ " value",
				(auto namedArgs) => namedArgs.map!(arg => arg.type.renderToString() ~ " " ~ arg.name).join(", ")
			);
		output ~= "    static " ~ sumTypeName(def) ~ " " ~ caseSpecName(c) ~ "(" ~ ctorParams ~ ") {\n";

		if (c.payload.isNameOnly()) {
			output ~= "        Content c;\n";

		} else if (auto singleType = c.payload.isSingleType()) {
			output ~= "        Content c = { " ~ caseFieldName(c, namingConvention) ~ ": value };\n";

		} else if (auto namedArgs = c.payload.isNamedArgs()) {
			auto fieldNames = (*namedArgs).map!(arg => arg.name).join(", ");
			output ~= "        Content c = { " ~ caseFieldName(c, namingConvention) ~ ": " ~ caseContentType(c, namingConvention) ~ "(" ~ fieldNames ~ ") };\n";
		}

		output ~= "        return " ~ sumTypeName(def) ~ "(Tag." ~ caseTagName(c, namingConvention) ~ ", c);\n";
		output ~= "    }\n";

		final switch (c.payload.tag()) with (CasePayload) {
			case Tag.NameOnly:
				// "is" checker
				output ~= "    bool " ~ caseIsName(c, namingConvention) ~ "() => _tag == Tag." ~ caseTagName(c, namingConvention) ~ ";\n";
				// no getter
				output ~= "    // name-only, no getter\n";
				break;
			case Tag.SingleType, Tag.NamedArgs:
				// "is" checker+getter
				output ~= "    " ~ caseContentType(c, namingConvention) ~ "* " ~ caseIsName(c, namingConvention) ~ "() => _tag == Tag." ~ caseTagName(c, namingConvention) ~ " ? &content." ~ caseFieldName(c, namingConvention) ~ " : null;\n";
				// force-getter
				output ~= "    ref " ~ caseContentType(c, namingConvention) ~ " " ~ caseGetterName(c, namingConvention) ~ "() {\n";
				output ~= "        enforce(_tag == Tag." ~ caseTagName(c, namingConvention) ~ ", \"" ~ sumTypeName(def) ~ "." ~ caseGetterName(c, namingConvention) ~ "(): tag doesn't match\");\n";
				output ~= "        return content." ~ caseFieldName(c, namingConvention) ~ ";\n";
				output ~= "    }\n";
				break;
		}
	}

	// multi-test
	output ~= "\n";
	output ~= "    // multi-test ==========================\n";
	auto isOneOfStr = namingConvention == NamingConvention.PascalCase ? "isOneOf" : "is_one_of";
	output ~= "    bool " ~ isOneOfStr ~ "(Tag[] tags ...) {
        foreach (t; tags) {
            if (t == _tag) return true;
        }
        return false;
    }
    bool " ~ isOneOfStr ~ "(string caseNames)() {
        import std.string: split;
        import std.algorithm : canFind;
        static immutable inputCases = caseNames.split(\", \");
        static assert(inputCases.length > 0, \"" ~ isOneOfStr ~ ": no case names provided\");
        final switch (_tag) {
";
	foreach (c; def.cases) {
		output ~= "            case Tag." ~ caseTagName(c, namingConvention) ~ ":\n";
		output ~= "                return inputCases.canFind(\"" ~ caseSpecName(c) ~ "\");\n";
	}
	output ~= "        }\n"; // end final switch
	output ~= "    }\n"; // end isOneOf()

	// exhaustive check
	output ~= "\n";
	auto isExhaustiveStr = namingConvention == NamingConvention.PascalCase ? "isExhaustive" : "is_exhaustive";
	output ~= "    // exhaustive check =======================
    // place in a static assert so you can catch all the places that need to be changed, when you add a new case
    static bool " ~ isExhaustiveStr ~ "(string caseNames)
    {
        import std.string: split;
        import std.algorithm.sorting: sort;
        auto inputCases = caseNames.split(\", \").sort();
";
	auto caseNames = def.cases.map!(c => "\"" ~ caseSpecName(c) ~ "\"").join(", ");
	output ~= "        auto checkAgainst = [" ~ caseNames ~ "].sort();\n";
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
				(auto nameOnly) => "        _MatchResult delegate(ref _NameOnly) " ~ caseFuncName(c, namingConvention) ~ "Func",
				(auto singleType) => "        _MatchResult delegate(ref " ~ caseContentType(c, namingConvention) ~ ") " ~ caseFuncName(c, namingConvention) ~ "Func",
				(auto namedArgs) => "        _MatchResult delegate(ref " ~ caseContentType(c, namingConvention) ~ ") " ~ caseFuncName(c, namingConvention) ~ "Func"
			)).join(",\n");

	output ~= delegateArgs ~ ")\n";
	output ~= "    {\n";
	output ~= "        _NameOnly fakeArg;\n";
	output ~= "        final switch(_tag) {\n";

	foreach (c; def.cases) {
		output ~= "            case Tag." ~ caseTagName(c, namingConvention) ~ ":\n";

		final switch (c.payload.tag()) with (CasePayload) {
			case Tag.NameOnly:
				output ~= "                return " ~ caseFuncName(c, namingConvention) ~ "Func(fakeArg);\n";
				break;
			case Tag.SingleType, Tag.NamedArgs:
				output ~= "                return " ~ caseFuncName(c, namingConvention) ~ "Func(content." ~ caseFieldName(c, namingConvention) ~ ");\n";
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
				(auto singleType) => singleType.renderToString() ~ " value",
				(auto namedArgs) => namedArgs.map!(arg => arg.type.renderToString() ~ " " ~ arg.name).join(", ")
			);
		output ~= "        _MatchResult " ~ caseFuncName(c, namingConvention) ~ "(" ~ args ~ ") => _any();\n";
	}
	output ~= "        _MatchResult _any() {\n";
	output ~= "            throw new Exception(\"" ~ sumTypeName(def) ~ ".Matcher._any() called, but not implemented\");\n";
	output ~= "        }\n";
	output ~= "    }\n"; // end Matcher base class

	// visit method
	output ~= "\n";
	output ~= "    _MatchResult match(_MatchResult)(Matcher!_MatchResult matcher) {\n";
	output ~= "        final switch(_tag) {\n";
	foreach (c; def.cases) {
		output ~= "            case Tag." ~ caseTagName(c, namingConvention) ~ ":\n";

		auto args =
			c.payload.match!string(
				(auto nameOnly) => "",
				(auto singleType) => "content." ~ caseFieldName(c, namingConvention),
				(auto namedArgs) => namedArgs.map!(arg => "content." ~ caseFieldName(c, namingConvention) ~ "." ~ arg.name).join(", ")
			);
		output ~= "                return matcher." ~ caseFuncName(c, namingConvention) ~ "(" ~ args ~ ");\n";
	}
	output ~= "        }\n"; // end final switch
	output ~= "    }\n"; // end match()

	output ~= "}\n"; // end struct

	return output[];
}
