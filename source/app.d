import std.stdio;
import std.format;

import bettersum: sumtype;

struct Woot(T) {
	T value;
}

enum Example = q{
Wondrous {
    Thing1,
    Thing2(Woot!(int[]) x),
    Thing3(string),
	Nice(int delegate() returnsInt),
	Doof,
	Whats(void delegate(string[])[string])
}
};

//mixin(sumtype(Example));

void main()
{
	writeln(sumtype(Example));
	// auto x = Wondrous.Thing3("helllooo");
	// auto y = Wondrous.Thing1();
	// auto z = Wondrous.Thing2(Woot!(int[])([1, 2, 3, 4, 5]));

	// if (x.isThing1()) {
	// 	writefln("is thing 1!");

	// } else if (auto thing2 = x.isThing2()) {
	// 	writefln("thing2: %s", thing2.x);

	// } else if (auto thing3 = x.isThing3()) {
	// 	writefln("thing3: [%s]", *thing3);
	// }

	// static assert(Wondrous.isExhaustive(q{Thing1, Thing2, Thing3}));
}
