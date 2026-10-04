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

enum FunctionAttr {
    Pure,
    NoThrow,
    Safe,
    NoGC
}

FunctionAttr functionAttrFromString(string attr) {
    switch (attr) {
        case "pure": return FunctionAttr.Pure;
        case "nothrow": return FunctionAttr.NoThrow;
        case "safe": return FunctionAttr.Safe;
        case "nogc": return FunctionAttr.NoGC;
        default:
            throw new Exception("functionAttrFromString() - unknown attr");
    }
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
    void ref_(DType content) {}
    void qualified(Qualifier qual, DType content, bool scoped) {}
    void primitive(string prim) {}
    void namedThing(string name, DType[] typeArgs, bool typeArgsWithParens) {}
    void dynamicArray(DType elem) {}
    void staticArray(DType elem, string length) {}
    void assocArray(DType key, DType value) {}
    void pointer(DType targetType) {}
    void callable(CallableKind kind, DType returnType, FunctionArg[] args, FunctionAttr[] attrs) {}
}

class DType {
    abstract void visit(Visitor v);
    abstract override string toString() const;
    abstract void prettyPrint(string prefix);
}

class Ref : DType {
    DType content;
    this(DType content) {
        this.content = content;
    }
    override string toString() const => format("Ref(%s)", content.toString());
    override void visit(Visitor v) => v.ref_(content);
    override void prettyPrint(string prefix) {
        writefln("%sRef(", prefix);
        content.prettyPrint(spacify(prefix) ~ "  ");
        writefln("%s)", spacify(prefix));
    }
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
    bool typeArgsWithParens;
    this(string name, DType[] typeArgs = [], bool typeArgsWithParens = false) {
        this.name = name;
        this.typeArgs = typeArgs;
        this.typeArgsWithParens = typeArgsWithParens;
    }
    override string toString() const {
        import std.array: join;
        import std.algorithm: map;
        if (typeArgs.length > 0) {
            auto joined = typeArgs.map!(ta => ta.toString()).join(",");
            auto args = typeArgsWithParens ? format("(%s)", joined) : joined;
            return format("NamedThing(%s!%s)", name, args);
        }
        return format("NamedThing(%s)", name);
    }
    override void visit(Visitor v) => v.namedThing(name, typeArgs, typeArgsWithParens);
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

class Pointer : DType {
    DType targetType;
    this(DType targetType) {
        this.targetType = targetType;
    }
    override string toString() const {
        return format("Pointer(%s)", targetType.toString());
    }
    override void visit(Visitor v) => v.pointer(targetType);
    override void prettyPrint(string prefix) {
        writefln("%sPointer(", prefix);
        targetType.prettyPrint(spacify(prefix ~ "  "));
        writefln("%s)", spacify(prefix));
    }
}

class Callable : DType {
    CallableKind kind;
    DType returnType;
    FunctionArg[] args;
    FunctionAttr[] attrs;
    this(string kind, DType returnType, FunctionArg[] args, FunctionAttr[] attrs) {
        this.kind = callableKindFromString(kind);
        this.returnType = returnType;
        this.args = args;
        this.attrs = attrs;
    }
    override string toString() const {
        import std.algorithm: map;
        import std.range: join;
        auto joinedArgs = args.map!(arg => format("Arg(type: %s, name: %s)", arg.type.toString(), arg.name !is null ? arg.name : "[none]")).join(", ");
        auto joinedAttrs = attrs.map!(attr => attr.to!string).join(", ");
        return format("Callable(kind: %s, returns: %s, args: [%s], attrs: [%s])", kind.to!string, returnType.toString(), joinedArgs, joinedAttrs);
    }
    override void visit(Visitor v) => v.callable(kind, returnType, args, attrs);
    override void prettyPrint(string prefix) {
        import std.algorithm: map;
        import std.range: join;
        writefln("%sCallable(", prefix);
        writefln("%s        kind: %s", spacify(prefix), kind.to!string);
        returnType.prettyPrint(spacify(prefix) ~ "  returnType: ");
        if (args.length == 0) {
            writefln("%s        args: [none]", spacify(prefix));
        } else {
            writefln("%s        args: (", spacify(prefix));
            foreach (arg; args) {
                arg.type.prettyPrint(format("%s           \"%s\": ", spacify(prefix), arg.name));
            }
            writefln("%s        )", spacify(prefix)); // end args
        }
        auto joinedAttrs = attrs.map!(attr => attr.to!string).join(", ");
        writefln("%s       attrs: [%s]", spacify(prefix), joinedAttrs);
        // end callable
        writefln("%s)", spacify(prefix));
    }
}

class Renderer : Visitor {
    string output;
    override void ref_(DType content) {
        output ~= "ref ";
        content.visit(this);
    }
    override void qualified(Qualifier qual, DType content, bool scoped) {
        final switch (qual) {
            case Qualifier.Const:
                output ~= "const";
                break;
            case Qualifier.Immutable:
                output ~= "immutable";
                break;
            case Qualifier.Shared:
                output ~= "shared";
                break;
        }
        if (scoped) {
            output ~= "(";
        } else {
            output ~= " ";
        }
        content.visit(this);
        if (scoped) {
            output ~= ")";
        }
    }
    override void primitive(string prim) {
        output ~= prim;
    }
    override void namedThing(string name, DType[] typeArgs, bool typeArgsWithParens) {
        import std.range: enumerate;
        output ~= name;
        if (typeArgs.length > 0) {
            output ~= "!";
            if (typeArgsWithParens) {
                output ~= "(";
            }
            foreach (i, ta; typeArgs.enumerate()) {
                if (i != 0) output ~= ",";
                ta.visit(this);
            }
            if (typeArgsWithParens) {
                output ~= ")";
            }
        }
    }
    override void dynamicArray(DType elem) {
        elem.visit(this);
        output ~= "[]";
    }
    override void staticArray(DType elem, string length) {
        elem.visit(this);
        output ~= format("[%d]", length);
    }
    override void assocArray(DType key, DType value) {
        value.visit(this);
        output ~= "[";
        key.visit(this);
        output ~= "]";
    }
    override void pointer(DType targetType) {
        targetType.visit(this);
        output ~= "*";
    }
    override void callable(CallableKind kind, DType returnType, FunctionArg[] args, FunctionAttr[] attrs) {
        import std.range: enumerate;
        returnType.visit(this);
        final switch (kind) {
            case CallableKind.Function:
                output ~= " function(";
                break;
            case CallableKind.Delegate:
                output ~= " delegate(";
                break;
        }
        foreach (i, arg; args) {
            if (i != 0) output ~= ", ";
            arg.type.visit(this);
            if (arg.name !is null) {
                output ~= " " ~ arg.name;
            }
        }
        output ~= ")";
        foreach (attr; attrs) {
            final switch (attr) with (FunctionAttr) {
                case Pure:
                    output ~= " pure";
                    break;
                case NoThrow:
                    output ~= " nothrow";
                    break;
                case Safe:
                    output ~= " @safe";
                    break;
                case NoGC:
                    output ~= " @nogc";
                    break;
            }
        }
    }
}

string renderToString(DType type) {
    auto renderer = new Renderer();
    type.visit(renderer);
    return renderer.output;
}
