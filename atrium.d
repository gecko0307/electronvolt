module atrium;

import std.stdio;
import dlib;
import dgl;
import game.config;
import game.app;

void main(string[] args)
{
    readConfig();

    writefln("Allocated memory at start: %s", allocatedMemory);
    loadLibraries();
    auto app = New!TestApp();
    app.run();
    Delete(app);
    writefln("Allocated memory at end: %s", allocatedMemory);
}

