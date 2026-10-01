module tokenizer;

import lexer;
import util;

private:

bool isKeyword(string str) {
	static known = setFromItems!string([
		"function", "delegate",
		"const", "immutable", "ref", "nothrow", "pure", "safe", "typeof"
	]);
	return (str in known) != null;
}

bool isPrimitive(string str) {
	static known = setFromItems!string([
		"void", "bool", "byte", "ubyte", "short", "ushort", "int", "uint", "long", "ulong", "cent", "ucent", "float",
		"double", "real", "ifloat", "idouble", "ireal", "cfloat", "cdouble", "creal", "char", "wchar", "dchar",
		"string"
	]);
	return (str in known) != null;
}

bool isSymbol(string str, out Token.Symbol sym) {
	static auto map = [
		"!": Token.Symbol.Bang,
		".": Token.Symbol.Dot,
		",": Token.Symbol.Comma,
		"(": Token.Symbol.LeftParen,
		")": Token.Symbol.RightParen,
		"[": Token.Symbol.LeftBracket,
		"]": Token.Symbol.RightBracket,
		"*": Token.Symbol.Star,
		"@": Token.Symbol.At,
		"{": Token.Symbol.LeftBrace,
		"}": Token.Symbol.RightBrace
	];
	if (auto found = str in map) {
		sym = *found;
		return true;
	}
	return false;
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
	if (i == str.length) {
		return true;
	}
	return false;
}

bool isNumericChar(char ch) {
	return (ch >= '0' && ch <= '9');
}

bool isNumeric(string str) {
	int i = 0;
	while (i < str.length && (isNumericChar(str[i]) || (i > 0 && str[i] == '_'))) {
		i++;
	}
	if (i == str.length) {
		return true;
	}
	return false;
}

Token[] classify(Chunk[] chunks) {
	Token[] result;
	foreach (ch; chunks) {
		Token.Symbol sym;
		if (isSymbol(ch.str, sym)) {
			result ~= Token.mkSymbol(sym, ch.line, ch.col);
		} else if (isPrimitive(ch.str)) {
			result ~= Token.mkPrimitive(ch);
		} else if(isKeyword(ch.str)) {
			result ~= Token.mkKeyword(ch);
		} else if (isNumeric(ch.str)) {
			result ~= Token.mkNumeric(ch);
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
		Primitive,
		Keyword,
		Identifier,
		Numeric,
		Symbol
	}
	enum Symbol {
		Bang,
		Dot,
		Comma,
		LeftParen,
		RightParen,
		LeftBracket,
		RightBracket,
		Star,
		At,
		LeftBrace,
		RightBrace
	}
	union Content {
		string text;
		Symbol symbol;
	}
	const Tag tag;
	Content content;
	const int line;
	const int col;

	static Token mkSymbol(Symbol symbol, int line, int col) {
		Content c = { symbol: symbol };
		return Token(Tag.Symbol, c, line, col);
	}

	static Token mkPrimitive(Chunk ch) {
		Content c = { text: ch.str };
		return Token(Tag.Primitive, c, ch.line, ch.col);
	}
	const(string)* isPrimitive() {
		if (tag == Tag.Primitive) {
			return &content.text;
		}
		return null;
	}

	static Token mkKeyword(Chunk ch) {
		Content c = { text: ch.str };
		return Token(Tag.Keyword, c, ch.line, ch.col);
	}
	const(string)* isKeyword() {
		if (tag == Tag.Keyword) {
			return &content.text;
		}
		return null;
	}

	static Token mkIdentifier(Chunk ch) {
		Content c = { text: ch.str };
		return Token(Tag.Identifier, c, ch.line, ch.col);
	}

	static Token mkNumeric(Chunk ch) {
		Content c = { text: ch.str };
		return Token(Tag.Numeric, c, ch.line, ch.col);
	}

	string toString() const {
		import std.format;
		import std.conv: to;
		final switch (tag) {
			case Tag.Keyword:
				return format("Keyword(%s)[%d:%d]", content.text, line, col);
			case Tag.Primitive:
				return format("Primitive(%s)[%d:%d]", content.text, line, col);
			case Tag.Identifier:
				return format("Identifier(%s)[%d:%d]", content.text, line, col);
			case Tag.Numeric:
				return format("Numeric(%s)[%d:%d]", content.text, line, col);
			case Tag.Symbol:
				return format("Symbol(%s)[%d:%d]", content.symbol.to!string, line, col);
		}
	}
}

Token[] tokenize(string input) {
    return classify(chunkify(input));
}
