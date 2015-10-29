module dgl.dml.stringconv;

import std.stdio;
import dlib.core.memory;
import dlib.container.array;
import std.conv;

// GC-free storage for dynamically generated strings

DynamicArray!string globalStringArray;

// TODO: replace std.conv.to with completely GC-free converter
string convToStr(T)(T v)
{
    string gcStr = to!string(v);
    ubyte[] cStr = New!(ubyte[])(gcStr.length);
    foreach(i, b; gcStr)
    {
        cStr[i] = b;
    }
    string str = cast(string)cStr;
    globalStringArray.append(str);
    return str;
}

void freeGlobalStringArray()
{
    foreach(s; globalStringArray)
    {
        Delete(s);
    }
    globalStringArray.free();
}