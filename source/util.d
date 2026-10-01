module util;

bool[K] setFromItems(K)(K[] keys) {
	bool[K] result;
	foreach (key; keys) {
		result[key] = true;
	}
	return result;
}
