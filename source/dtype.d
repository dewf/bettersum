module dtype;

import std.format;
import std.stdio;
import std.conv: to;

struct FunctionArg {
    DType type;
    string name; // or null
}

enum CallableKind {
    Function,
    Delegate
}

string spacify(string prefix) {
    import std.array: replicate;
    return " ".replicate(prefix.length);
}

CallableKind callableKindFromString(string kind) {
    with(CallableKind) {
        if (kind == "function") return Function;
        if (kind == "delegate") return Delegate;
        throw new Exception("callableKindFromString: unknown kind");
    }
}

// string callableKindToString(CallableKind kind) {
//     with(CallableKind)
//     final switch (kind) {
//         case Function: return "function";
//         case Delegate: return "delegate";
//     }
// }

enum Qualifier {
    Const,
    Immutable,
    Shared
}

Qualifier qualifierFromString(string qual) {
    switch (qual) {
        case "const":
            return Qualifier.Const;
        case "immutable":
            return Qualifier.Immutable;
        case "shared":
            return Qualifier.Shared;
        default:
            throw new Exception("qualifierFromString: unhandled qual [" ~ qual ~ "]");
    }
}

class Visitor {
    void qualified(Qualifier qual, DType content, bool scoped) {}
    void primitive(string prim) {}
    void namedThing(string name, DType[] typeArgs) {}
    void dynamicArray(DType elem) {}
    void staticArray(DType elem, string length) {}
    void assocArray(DType key, DType value) {}
    void callable(CallableKind kind, DType returnType, FunctionArg[] args) {}
}

class DType {
    abstract void visit(Visitor v);
    abstract override string toString() const;
    abstract void prettyPrint(string prefix);
}

class Qualified : DType {
    Qualifier qual;
    DType content;
    bool scoped; // parenthesized
    this(string qual, DType content, bool scoped) {
        this.qual = qualifierFromString(qual);
        this.content = content;
        this.scoped = scoped;
    }
    override string toString() const => format("%s(%s)", qual.to!string, content.toString());
    override void visit(Visitor v) => v.qualified(qual, content, scoped);
    override void prettyPrint(string prefix) {
        writefln("%s%s%s(", prefix, qual.to!string, scoped ? "[scoped]" : "");
        content.prettyPrint(spacify(prefix) ~ "  ");
        writefln("%s)", spacify(prefix));
    }
}

class Primitive : DType {
    string prim;
    this(string prim) {
        this.prim = prim;
    }
    override string toString() const => format("Primitive(%s)", prim);
    override void visit(Visitor v) => v.primitive(prim);
    override void prettyPrint(string prefix) {
        writefln("%s%s", prefix, toString());
    }
}

class NamedThing: DType {
    string name;
    DType[] typeArgs;
    this(string name, DType[] typeArgs = []) {
        this.name = name;
        this.typeArgs = typeArgs;
    }
    override string toString() const {
        import std.array: join;
        import std.algorithm: map;
        if (typeArgs.length > 0) {
            auto joined = typeArgs.map!(ta => ta.toString()).join(",");
            return format("NamedThing(%s!(%s))", name, joined);
        }
        return format("NamedThing(%s)", name);
    }
    override void visit(Visitor v) => v.namedThing(name, typeArgs);
    override void prettyPrint(string prefix) {
        if (typeArgs.length > 0) {
            writefln("%sNamedThing(%s![", prefix, name);
            foreach (arg; typeArgs) {
                arg.prettyPrint(spacify(prefix) ~ "  ");
            }
            writefln("%s])", spacify(prefix));
        } else {
            writefln("%sNamedThing(%s)", spacify(prefix), name);
        }
    }
}

class DynamicArray : DType {
    DType elem;
    this(DType elem) {
        this.elem = elem;
    }
    override string toString() const => format("DynamicArray(elem: %s)", elem.toString());
    override void visit(Visitor v) => v.dynamicArray(elem);
    override void prettyPrint(string prefix) {
        writefln("%sDynamicArray(", prefix);
        elem.prettyPrint(spacify(prefix) ~ "  elem: ");
        writefln("%s)", spacify(prefix));
    }
}

class StaticArray : DType {
    DType elem;
    string length;
    this(DType elem, string length) {
        this.elem = elem;
        this.length = length;
    }
    override string toString() const => format("StaticArray(elem: %s, len: %s)", elem.toString(), length);
    override void visit(Visitor v) => v.staticArray(elem, length);
    override void prettyPrint(string prefix) {
        writefln("%sStaticArray(", prefix);
        writefln("%s    length: %d", length);
        elem.prettyPrint(prefix ~ "    elem:");
        writefln("%s)", prefix);
    }
}

class AssocArray : DType {
    DType key, value;
    this(DType key, DType value) {
        this.key = key;
        this.value = value;
    }
    override string toString() const => format("AssocArray(key: %s, value: %s)", key.toString(), value.toString());
    override void visit(Visitor v) => v.assocArray(key, value);
    override void prettyPrint(string prefix) {
        writefln("%sAssocArray(", prefix);
        key.prettyPrint(spacify(prefix) ~ "    key: ");
        value.prettyPrint(spacify(prefix) ~ "  value: ");
        writefln("%s)", spacify(prefix));
    }
}

class Callable : DType {
    CallableKind kind;
    DType returnType;
    FunctionArg[] args;
    this(string kind, DType returnType, FunctionArg[] args) {
        this.kind = callableKindFromString(kind);
        this.returnType = returnType;
        this.args = args;
    }
    override string toString() const {
        import std.algorithm: map;
        import std.range: join;
        auto joined = args.map!(arg => format("Arg(type: %s, name: %s)", arg.type.toString(), arg.name !is null ? arg.name : "[none]")).join(", ");
        return format("Callable(kind: %s, returns: %s, args: [%s])", kind.to!string, returnType.toString(), joined);
    }
    override void visit(Visitor v) => v.callable(kind, returnType, args);
    override void prettyPrint(string prefix) {
        writefln("%sCallable(", prefix);
        writefln("%s  - kind: %s", prefix, kind.to!string);
        returnType.prettyPrint(prefix ~ "  - returnType: ");
        writefln("%s  - args(", prefix);
        foreach (arg; args) {
            arg.type.prettyPrint(format("%s    \"%s\": ", prefix, arg.name));
        }
        writefln("%s    )", prefix); // end args
        // end callable
        writefln("%s)", prefix);
    }
}
