import std.stdio;
import std.format;

import bettersum: sumtype;

enum Example = q{
Wondrous {
	Thing1,            // `comment 1`
	Thing2(int[] x),   // `comment 2`
	Thing3(string),    // `comment 3`
	Thing4(int, string, int)
}};

// mixin(sumtype(}));
// 	// broken!!!
// 	// Thing5(int, string, int)

void main()
{
	writeln(sumtype(Example));
	// auto x =
	// 	// Wondrous.makeThing1();
	// 	// Wondrous.makeThing2([1, 2, 3, 4, 5]);
	// 	Wondrous.makeThing3("helllooo");

	// if (x.isThing1()) {
	// 	writefln("is thing 1!");

	// } else if (auto thing2 = x.isThing2()) {
	// 	writefln("thing2: %s", thing2.x);

	// } else if (auto thing3 = x.isThing3()) {
	// 	writefln("thing3: [%s]", *thing3);
	// }

	// static assert(Wondrous.isExhaustive(q{Thing1, Thing2, Thing3}));
}
