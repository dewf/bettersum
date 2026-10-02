module dtype;

import std.format;

class Visitor {
    void primitive(string prim) {}
    void namedThing(string name) {}
    void dynamicArray(DType elem) {}
    void staticArray(DType elem, string length) {}
    void assocArray(DType key, DType value) {}
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
    // TODO: type args
    this(string name) {
        this.name = name;
    }
    override string toString() const => format("NamedThing(%s)", name);
    override void visit(Visitor v) => v.namedThing(name);
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
