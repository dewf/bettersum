module util;

bool[K] aaFromItems(K)(K[] keys) {
	bool[K] result;
	foreach (key; keys) {
		result[key] = true;
	}
	return result;
}
