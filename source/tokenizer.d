module tokenizer;

import lexer;
import util;

private:

bool isKeyword(string str) {
	static known = aaFromItems!string([
		"void", "bool", "byte", "ubyte", "short", "ushort", "int", "uint", "long", "ulong", "cent", "ucent", "float",
		"double", "real", "ifloat", "idouble", "ireal", "cfloat", "cdouble", "creal", "char", "wchar", "dchar",
		"function", "delegate",
		"const", "immutable", "ref", "nothrow", "pure", "safe", "typeof"
	]);
	return (str in known) != null;
}

bool isSymbol(string str) {
	static auto known = aaFromItems!string(["!", ".", ",", "(", ")", "[", "]", "*", "@", "{", "}"]);
	return (str in known) !=  null;
}

bool isIdentifierChar(char ch, bool isFirstChar = false) {
	if (isFirstChar) {
		return
			(ch >= 'A' && ch <= 'Z') ||
			(ch >= 'a' && ch <= 'z') ||
			(ch == '_');
	} else {
		return
			(ch >= 'A' && ch <= 'Z') ||
			(ch >= 'a' && ch <= 'z') ||
			(ch >= '0' && ch <= '9') ||
			(ch == '_');
	}
}

bool isIdentifier(string str) {
	int i = 0;
	while (i < str.length) {
		if (!isIdentifierChar(str[i], i == 0)) {
			return false;
		}
		i++;
	}
	if (i > 0) {
		return true;
	}
	return false;
}

Token[] classify(Chunk[] chunks) {
	Token[] result;
	foreach (ch; chunks) {
		if (isSymbol(ch.str)) {
			result ~= Token.mkSymbol(ch);
		} else if(isKeyword(ch.str)) {
			result ~= Token.mkKeyword(ch);
		} else if (isIdentifier(ch.str)) {
			result ~= Token.mkIdentifier(ch);
		} else {
			throw new Exception("could not classify lexed chunk: [" ~ ch.str ~ "]");
		}
	}
	return result;
}

public:

struct Token {
	enum Tag {
		Keyword,
		Identifier,
		Symbol
	}
	union Content {
		string keyword;
		string identifier;
		string symbol;
	}
	const Tag tag;
	const Content content;
	const int line;
	const int col;

	static Token mkKeyword(Chunk ch) {
		Content c = { keyword: ch.str };
		return Token(Tag.Keyword, c, ch.line, ch.col);
	}

	static Token mkIdentifier(Chunk ch) {
		Content c = { identifier: ch.str };
		return Token(Tag.Identifier, c, ch.line, ch.col);
	}

	static Token mkSymbol(Chunk ch) {
		Content c = { symbol: ch.str };
		return Token(Tag.Symbol, c, ch.line, ch.col);
	}

	string toString() const {
		import std.format;
		final switch (tag) {
			case Tag.Keyword:
				return format("Keyword(%s)[%d:%d]", content.keyword, line, col);
			case Tag.Identifier:
				return format("Identifier(%s)[%d:%d]", content.identifier, line, col);
			case Tag.Symbol:
				return format("Symbol(%s)[%d:%d]", content.symbol, line, col);
		}
	}
}

Token[] tokenize(string input) {
    return classify(chunkify(input));
}
