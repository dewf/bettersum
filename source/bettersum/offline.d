module bettersum.offline;

import bettersum.parser;
import bettersum.renderer;
import bettersum.tokenizer: Location;

public import bettersum.options;

import std.format;

OfflineResult sumtype(string input, SumtypeOptions options = SumtypeOptions()) {
	auto result = parseSumType(input);
	if (auto def = result.isSuccess()) {

        auto text = renderSumType(def.thing, options);
        return OfflineResult.Success(text);

	} else if (auto err = result.isError()) {
        return OfflineResult.Error(err.message, err.loc);
	}

	// else some neutral failure, which shouldn't be possoble (parseSumType should always error)
    return OfflineResult.Error("sumtype: unknown parse error", Location());
}

OfflineResult sumtype(string input, NamingConvention nc) {
	SumtypeOptions options = { namingConvention: nc };
	return sumtype(input, options);
}

struct OfflineResult {
    import std.exception: enforce;
private:
    // Success: name + single type, no fields
    struct _Error { string message; Location loc; }

    union Content {
        string success;
        _Error error;
    }
    Tag _tag;
    Content content;
public:
    enum Tag { Success, Error }
    Tag tag() => _tag;

    // Success ==================================
    static OfflineResult Success(string value) {
        Content c = { success: value };
        return OfflineResult(Tag.Success, c);
    }
    string* isSuccess() => _tag == Tag.Success ? &content.success : null;
    ref string getSuccess() {
        enforce(_tag == Tag.Success, "OfflineResult.getSuccess(): tag doesn't match");
        return content.success;
    }

    // Error ==================================
    static OfflineResult Error(string message, Location loc) {
        Content c = { error: _Error(message, loc) };
        return OfflineResult(Tag.Error, c);
    }
    _Error* isError() => _tag == Tag.Error ? &content.error : null;
    ref _Error getError() {
        enforce(_tag == Tag.Error, "OfflineResult.getError(): tag doesn't match");
        return content.error;
    }

    static bool isExhaustive(string caseNames)
    {
        import std.string: split;
        import std.algorithm.sorting: sort;
        auto inputCases = caseNames.split(", ").sort();
        auto checkAgainst = ["Success", "Error"].sort();
        return inputCases == checkAgainst;
    }
}
