module atrium;

import std.stdio;
import dlib;
import dgl;
import game.config;
import game.app;

void main(string[] args)
{
    loadLibraries();
    readConfig();

    writefln("Allocated memory at start: %s", allocatedMemory);
    auto app = New!GameApp();
    app.run();
    Delete(app);
    writefln("Allocated memory at end: %s", allocatedMemory);
    //printMemoryLog();
}
