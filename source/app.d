import std.stdio;
import std.format;

import parser;
import renderer;

enum Example = q{
Wondrous {
	Thing1,
	Thing2(int[] x),
	Thing3(string y)
}
};

void main()
{
	auto defResult = parseSumType(Example);
	if (auto def = defResult.isSuccess()) {
		writeln(renderSumType(def.thing));
	} else if (auto err = defResult.isError()) {
		writefln("parse error: [%s]%s", err.message, err.loc);
	} else {
		writefln("simply failed to parse");
	}
}
