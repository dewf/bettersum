module bettersum;

import bettersum.parser;
import bettersum.renderer;

import std.format;

string sumtype(string input, string file = __FILE__, size_t line = __LINE__) {
	try {
		auto result = parseSumType(input);
		if (auto def = result.isSuccess()) {

			return renderSumType(def.thing);

		} else if (auto err = result.isError()) {
			return format("static assert(0, \"sumtype (file [%s], line %d): parse error [%s]%s\");", file, line, err.message, err.loc);
		}

		// else failed to parse
		return format("static assert(0, \"sumtype: bad format (file [%s], line %d)\");", file, line);

	} catch (Exception e) {
		return format("static assert(0, \"sumtype (file [%s], line %d): caught exception while parsing - probably a lexer issue\");", file, line);
	}
}
