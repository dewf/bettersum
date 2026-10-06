module bettersum;

import bettersum.parser;
import bettersum.renderer;

import std.format;

public import bettersum.options;

string sumtype(string input, SumtypeOptions options = SumtypeOptions(), string file = __FILE__, size_t line = __LINE__) {
	auto result = parseSumType(input);
	if (auto def = result.isSuccess()) {

		return renderSumType(def.thing, options);

	} else if (auto err = result.isError()) {
		return format("static assert(0, \"sumtype (file [%s], line %d): %s %s\");", file, line, err.message, err.loc);
	}

	// else some neutral failure, which shouldn't be possoble (parseSumType should always error)
	return format("static assert(0, \"sumtype: bad format (file [%s], line %d)\");", file, line);
}
