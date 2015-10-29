module atrium;

import std.stdio;
import dlib;
import dgl;
import dgl.dml.stringconv;
import game.config;
import game.app;

void main(string[] args)
{
    writefln("Allocated memory at start: %s", allocatedMemory);  
    loadLibraries();
    readConfig();     
    auto app = New!GameApp();
    app.run();
    Delete(app);
    config.free();
    freeGlobalStringArray();
    writefln("Allocated memory at end: %s", allocatedMemory);
    //printMemoryLog();
}
