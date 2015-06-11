module game.config;

import std.stdio;
import std.file;
import dgl.dml.dml;

DMLData config;

void readConfig()
{
	config.set("enableShadows", "1");
    config.set("shadowMapSize", "512");
    config.set("enableShaders", "1");
    config.set("videoWidth", "800");
    config.set("videoHeight", "600");
	
	if (!parseDML(readText("game.conf"), &config))
	{
	    writeln("Failed to read config \"game.conf\"");
	}
}