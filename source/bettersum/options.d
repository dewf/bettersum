module bettersum.options;

import std.typecons: Nullable, nullable;

enum NamingConvention {
	PascalCase,
	SnakeCase
}

struct SumtypeOptions {
	Nullable!NamingConvention namingConvention;
	int tabWidth = 4; // for error messages, since q{} strings in vscode/code-d seem to use tabs :(
}
