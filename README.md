# bettersum
mixin-based sumtypes for D

(Use the companion project [sumgen](https://github.com/dewf/sumgen) if you'd prefer to insert the generated code directly into .d files)

example usage:

```d
import std.stdio;
import std.format;

import bettersum;

// recommended usage style (so error line numbers match):
mixin(sumtype(q{
CoolThing(T) {
    Red,                     // name only, no payload
    Green(int x),            // named-field payload
    Blue(string),            // single type-only payload
    Yellow(T),               // same
    Orange(int x, string y)  // multi-field payload

	// Zebra(int, int, int)   // tuple-style payload, not supported
}}));

alias BetterThing = CoolThing!float;

void main()
{
	// use case constructors to make values:
	auto x = BetterThing.Red();
	auto y = BetterThing.Yellow(1.333333);
	auto z = BetterThing.Orange(123, "hi");

	auto thing = BetterThing.Green(1234);

	// switch-style matching (ugly, but sometimes helpful)
    // use .get<Case> getters to access payload
	with(BetterThing)
	final switch(thing.tag) {
		case Tag.Red:
			writeln("red"); // no payload, nothing to get
			break;
		case Tag.Green:
			writefln("green(%d)", thing.getGreen().x); // uses named field: .x
			break;
		case Tag.Blue:
			writefln("blue(%s)", thing.getBlue()); // type-only payload, no field name necessary
			break;
		case Tag.Yellow:
			writefln("yellow(%.2f)", thing.getYellow()); // same as above
			break;
		case Tag.Orange:
			writefln("orange(%d, %s)", thing.getOrange().x, thing.getOrange().y); // named fields
			break;
	}

	// if-style matching (a little nicer)
	if (thing.isRed()) {
        // for name-only cases, .is<Case> returns bool
		writeln("red");

	} else if (auto green = thing.isGreen()) {
		// ... otherwise it returns a pointer to the payload
		writefln("green(%d)", green.x);

	} else if (auto blue = thing.isBlue()) {
		// you'll have to explicitly dereference for single-type payloads
		writefln("blue(%s)", *blue);

	} else {
		// etc - handle all other cases
		// (you'll have to use .get<Case> getters if you need something specific)
	}

	// a manual checksum of sorts: put this after any if-style match,
	//   to indicate all the cases you handled.
	// if a new one gets added later, it will fail to compile
	static assert(BetterThing.isExhaustive(q{Red, Green, Blue, Yellow, Orange}));

	// tag-based testing
	with(BetterThing)
	if (thing.isOneOf(Tag.Red, Tag.Blue)) {
	}

	// string-based testing (note this is a compile-time argument)
	if (thing.isOneOf!q{Red, Blue}) {
	}

	// simple delegate-style matching:
	// all cases must be handled, in order
	auto result =
		thing.match!string(
			(auto red) => "red",
			(auto green) => format("green(%d)", green.x),
			(auto blue) => format("blue(%s)", blue),
			(auto yellow) => format("yellow(%.2f)", yellow),
			(auto orange) => format("orange(%d, %s)", orange.x, orange.y)
		);

	// more flexible visitor-style matching
	auto result2 =
		thing.match(
			new class BetterThing.Matcher!int {
				// only handle what you care about
				override int red() => 1;
				override int green(int x) => 2;

				// default handler, for anything you don't override
				// MUST be implemented if you don't handle all cases
				override int _any() => 100;

				// our default handler will catch these:
				// override int blue(string value) => ... ;
				// override int yellow(float value) => ... ;
				// override int orange(int x, string y) => ... ;
			}
		);

	// hybrid "if-style expression" style
	auto result3 = () {
		if (thing.isRed()) {
			return "red";
		} else if (auto green = thing.isGreen()) {
			return format("green: %d", green.x);
		} else {
			return "other";
		}
	}();
}
```
