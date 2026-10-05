module bettersum.lexer;

import bettersum.util;
import stonesoup.unit: Unit;

private:

bool backticked(string input, out string value) {
	if (input.length < 2) return false;
	if (input[0] == '`') {
		// find matching
		int i = 1;
		while (i < input.length) {
			if (input[i] == '`') {
				value = input[0..i+1]; // include backticks (for classifier)
				return true;
			} else if (input[i] == '\n') {
				throw new Exception("lexer: newlines not allowed in backticked expression");
			}
			i++;
		}
		// else no matching backtick found, fall through
	}
	return false;
}

bool alphaNumeric(string input, out string value) {
	bool isAlphaNumeric(char ch) {
		return
			(ch >= 'A' && ch <= 'Z') ||
			(ch >= 'a' && ch <= 'z') ||
			(ch >= '0' && ch <= '9') ||
			ch == '_';
	}
	int i = 0;
	while (i < input.length && isAlphaNumeric(input[i])) {
		i++;
	}
	if (i > 0) {
		value = input[0..i];
		return true;
	}
	return false;
}

immutable auto knownSymbols = setFromItems!char(['!', '.', ',', '(', ')', '[', ']', '*', '@', '{', '}']);

bool symbol(string input, out string value) {
	if (input.length > 0 && input[0] in knownSymbols) {
		value = [input[0]];
		return true;
	}
	return false;
}

struct PosDelta {
	int lines;
	int cols;
}

bool whitespace(string input, out string value, out PosDelta outDelta) {
	bool isWhitespace(char ch, out PosDelta outCharDelta) {
		switch (ch) {
			case ' ':
				outCharDelta = PosDelta(0, 1);
				return true;
			case '\t':
				outCharDelta = PosDelta(0, 4); // uhhh
				return true;
			case '\r':
				outCharDelta = PosDelta(0, 0);
				return true;
			case '\n':
				outCharDelta = PosDelta(1, 0);
				return true;
			default:
				return false;
		}
	}
	int i = 0;
	PosDelta charDelta, total;
	while (i < input.length && isWhitespace(input[i], charDelta)) {
		if (charDelta.lines > 0) {
			total.cols = 0;
		}
		total.lines += charDelta.lines;
		total.cols += charDelta.cols;
		i++;
	}
	if (i > 0) {
		value = input[0..i];
		outDelta = total;
		return true;
	}
	return false;
}

public:

struct Chunk {
	string str;
	int line;
	int col;
}

Chunk[] chunkify(string input) {
	Chunk[] output;
	int line;
	int col;
	string current;
	PosDelta delta;
	size_t i;
	while (i < input.length) {
		if (backticked(input[i..$], current)) {
			output ~= Chunk(current, line, col);
			col += current.length;
			i += current.length;
		} else if (alphaNumeric(input[i..$], current)) {
			output ~= Chunk(current, line, col);
			col += current.length;
			i += current.length;
		} else if (symbol(input[i..$], current)) {
			output ~= Chunk(current, line, col);
			col += current.length;
			i += current.length;
		} else if (whitespace(input[i..$], current, delta)) {
			if (delta.lines > 0) {
				col = 0;
			}
			line += delta.lines;
			col += delta.cols;
			i += current.length;
		} else {
			throw new Exception("unhandle-able character: " ~ input[i]);
		}
	}
	return output;
}
