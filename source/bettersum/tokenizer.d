module bettersum.tokenizer;

import bettersum.lexer;
import bettersum.util;

import stonesoup.sumtype: sumtype;

private:

immutable auto knownKeywords = setFromItems!string([
	// storage:
	"ref",
	// type qualifiers:
	"const", "immutable", "shared", "inout",
	// callables:
	"function", "delegate",
	// function type attrs:
	"pure", "nothrow",
	// function type attrs (@ prefix)
	"safe", "nogc",
	// misc
	"typeof"
]);

immutable auto knownPrimitives = setFromItems!string([
	"void", "bool", "byte", "ubyte", "short", "ushort", "int", "uint", "long", "ulong", "cent", "ucent", "float",
	"double", "real", "ifloat", "idouble", "ireal", "cfloat", "cdouble", "creal", "char", "wchar", "dchar",
	"string"
]);

immutable auto symbolMap = [
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

bool isKeyword(string str) {
	return (str in knownKeywords) != null;
}

bool isPrimitive(string str) {
	return (str in knownPrimitives) != null;
}

bool isSymbol(string str, out Token.Symbol sym) {
	if (auto found = str in symbolMap) {
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

bool isBackticked(string str) {
	return str[0] == '`' && str[$-1] == '`';
}

bool isComment(string str) {
	import std.string: startsWith;
	return str.startsWith("//");
}

mixin(sumtype(q{
TokenResult {
	Success(`Token[]`),
	Error(`string` message, `Location` loc)
}
}));

TokenResult classify(Chunk[] chunks) {
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
		} else if (isBackticked(ch.str)) {
			result ~= Token.mkBackticked(ch);
		} else if (isComment(ch.str)) {
			// ignore it!
		}
		else {
			return TokenResult.makeError("could not classify lexed chunk: [" ~ ch.str ~ "]", Location(ch.line, ch.col));
		}
	}
	return TokenResult.makeSuccess(result);
}

public:

struct Location {
	int line;
	int col;
	this(int line, int col) {
		this.line = line;
		this.col = col;
	}
	this(Chunk ch) {
		line = ch.line;
		col = ch.col;
	}
	string toString() const {
		import std.format;
		return format("[%d:%d]", line, col);
	}
}

struct Token {
	enum Tag {
		Primitive,
		Keyword,
		Identifier,
		Numeric,
		Symbol,
		Backticked
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
	Location loc;

	static Token mkSymbol(Symbol symbol, int line, int col) {
		Content c = { symbol: symbol };
		return Token(Tag.Symbol, c, Location(line, col));
	}
	const(Symbol)* isSymbol() {
		if (tag == Tag.Symbol) {
			return &content.symbol;
		}
		return null;
	}

	static Token mkPrimitive(Chunk ch) {
		Content c = { text: ch.str };
		return Token(Tag.Primitive, c, Location(ch));
	}
	const(string)* isPrimitive() {
		if (tag == Tag.Primitive) {
			return &content.text;
		}
		return null;
	}

	static Token mkKeyword(Chunk ch) {
		Content c = { text: ch.str };
		return Token(Tag.Keyword, c, Location(ch));
	}
	const(string)* isKeyword() {
		if (tag == Tag.Keyword) {
			return &content.text;
		}
		return null;
	}

	static Token mkIdentifier(Chunk ch) {
		Content c = { text: ch.str };
		return Token(Tag.Identifier, c, Location(ch));
	}
	const(string)* isIdentifier() {
		if (tag == Tag.Identifier) {
			return &content.text;
		}
		return null;
	}

	static Token mkNumeric(Chunk ch) {
		Content c = { text: ch.str };
		return Token(Tag.Numeric, c, Location(ch));
	}
	const(string)* isNumeric() {
		if (tag == Tag.Numeric) {
			return &content.text;
		}
		return null;
	}

	static Token mkBackticked(Chunk ch) {
		Content c = { text: ch.str[1..$-1] }; // strip backticks
		return Token(Tag.Backticked, c, Location(ch));
	}
	const(string)* isBackticked() {
		if (tag == Tag.Backticked) {
			return &content.text;
		}
		return null;
	}

	string toString() const {
		import std.format;
		import std.conv: to;
		final switch (tag) {
			case Tag.Keyword:
				return format("Keyword(%s)%s", content.text, loc);
			case Tag.Primitive:
				return format("Primitive(%s)%s", content.text, loc);
			case Tag.Identifier:
				return format("Identifier(%s)%s", content.text, loc);
			case Tag.Numeric:
				return format("Numeric(%s)%s", content.text, loc);
			case Tag.Symbol:
				return format("Symbol(%s)%s", content.symbol.to!string, loc);
			case Tag.Backticked:
				return format("Backticked(%s)%s", content.text, loc);
		}
	}
}

TokenResult tokenize(string input) {
	auto chunksResult = chunkify(input);
	if (auto chunks = chunksResult.isSuccess()) {
		return classify(*chunks);
	} else if (auto err = chunksResult.isError()) {
		// re-raise
		return TokenResult.makeError(err.message, Location(err.line, err.col));
	}
	static assert(TokenResult.isExhaustive(q{Success, Error}));
	// unreachable
	assert(0);
}
