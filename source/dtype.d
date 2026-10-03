module dtype;

import std.format;

struct FunctionArg {
    DType type;
    string name; // or null
}

enum CallableKind {
    Function,
    Delegate
}

CallableKind callableKindFromString(string kind) {
    with(CallableKind) {
        if (kind == "function") return Function;
        if (kind == "delegate") return Delegate;
        throw new Exception("callableKindFromString: unknown kind");
    }
}

string callableKindToString(CallableKind kind) {
    with(CallableKind)
    final switch (kind) {
        case Function: return "function";
        case Delegate: return "delegate";
    }
}

class Visitor {
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
}

class Primitive : DType {
    string prim;
    this(string prim) {
        this.prim = prim;
    }
    override string toString() const => format("Primitive(%s)", prim);
    override void visit(Visitor v) => v.primitive(prim);
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
}

class DynamicArray : DType {
    DType elem;
    this(DType elem) {
        this.elem = elem;
    }
    override string toString() const => format("DynamicArray(elem: %s)", elem.toString());
    override void visit(Visitor v) => v.dynamicArray(elem);
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
}


class AssocArray : DType {
    DType key, value;
    this(DType key, DType value) {
        this.key = key;
        this.value = value;
    }
    override string toString() const => format("AssocArray(key: %s, value: %s)", key.toString(), value.toString());
    override void visit(Visitor v) => v.assocArray(key, value);
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
        return format("Callable(kind: %s, returns: %s, args: [%s])", callableKindToString(kind), returnType.toString(), joined);
    }
    override void visit(Visitor v) => v.callable(kind, returnType, args);
}
