module stockd.defs.common;

import std.string : format;

mixin template property(T, string name)
{
    mixin(format("private T _%s;
                 @nogc @safe @property pure nothrow public T %s() const { return _%s; }
                 @nogc @safe @property pure nothrow public void %s(T value) { _%s = value; }", 
                 name, name, name, name, name));
}

mixin template property(T, string name, T init)
    if(is(T:double) || is(T:float) || is(T:real) || is(T:string))
{
    mixin(format("private T _%s = %s;
                 @nogc @safe @property pure nothrow public T %s() const { return _%s; }
                 @nogc @safe @property pure nothrow public void %s(T value) { _%s = value; }", 
                 name, init.stringof, name, name, name, name));
}

@trusted pure nothrow debug auto trustedPureDebugCall (alias fn, A...) (A args)
{
    try
    {
        debug return fn(args);
    }catch{}
}