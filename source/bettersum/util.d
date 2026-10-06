module bettersum.util;

import std.typecons: Nullable;

bool[K] setFromItems(K)(K[] keys) {
	bool[K] result;
	foreach (key; keys) {
		result[key] = true;
	}
	return result;
}

T getOrDefault(T)(Nullable!T thing, T defaultValue) {
	if (thing.isNull()) {
		return defaultValue;
	}
	return thing.get();
}
