import std.stdio;
import std.format;

import bettersum: sumtype;

mixin(sumtype(q{
Wondrous {
	Thing1,
	Thing2(int[] x),
	Thing3(string)
}
}));
	// broken!!!
	// Thing5(int, string, int)

void main()
{
	auto x =
		// Wondrous.makeThing1();
		// Wondrous.makeThing2([1, 2, 3, 4, 5]);
		Wondrous.makeThing3("helllooo");

	if (auto thing1 = x.isThing1()) {
		writefln("is thing 1!");

	} else if (auto thing2 = x.isThing2()) {
		writefln("thing2: %s", thing2.x);

	} else if (auto thing3 = x.isThing3()) {
		writefln("thing3: [%s]", *thing3);
	}

	static assert(Wondrous.isExhaustive(q{Thing1, Thing2, Thing3}));
}
