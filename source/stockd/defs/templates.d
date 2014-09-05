module stockd.defs.templates;

import std.string : format;

mixin template property(T, string name)
{
    mixin(format("private T _%s;
                 @property @safe @nogc pure nothrow public T %s() const { return _%s; }
                 @property @safe @nogc pure nothrow public void %s(T value) { _%s = value; }", 
                 name, name, name, name, name));
}

mixin template property(T, string name, T init)
    if(is(T:double) || is(T:float) || is(T:real) || is(T:string))
{
    mixin(format("private T _%s = %s;
                 @property @safe @nogc pure nothrow public T %s() const { return _%s; }
                 @property @safe @nogc pure nothrow public void %s(T value) { _%s = value; }", 
                 name, init.stringof, name, name, name, name));
}
