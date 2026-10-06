module bettersum.options;

import std.typecons: Nullable, nullable;

enum NamingConvention {
	PascalCase,
	SnakeCase
}

struct SumtypeOptions {
	Nullable!NamingConvention namingConvention;
}
