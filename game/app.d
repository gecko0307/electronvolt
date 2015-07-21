module game.app;

import dlib;
import dgl;
import game.loading;
import game.pause;
import game.scene3d;
import game.config;

class GameApp: RoomApplication
{
    ResourceManager rm;
    LoadingRoom loading;
    Scene3DRoom room3d;
    
    int videoWidth()
    {
        return config["videoWidth"].toInt;
    }
    
    int videoHeight()
    {
        return config["videoHeight"].toInt;
    }
    
    this()
    {
        super(videoWidth(), videoHeight(), "Atrium");

        exitOnEscapePress = false;
        
        clearColor = Color4f(0.0f, 0.0f, 0.0f);

        rm = New!ResourceManager();
        rm.fs.mount("data");
        
        auto fontDroid18 = New!FreeTypeFont("data/fonts/droid/DroidSans.ttf", 18);
        rm.addFont("Droid", fontDroid18);
        
        addRoom("pause", New!PauseRoom(eventManager, this));
        setCurrentRoom("pause", false);
        
        loading = New!LoadingRoom(eventManager, this);
        addRoom("loading", loading);

        room3d = New!Scene3DRoom(eventManager, this);
        addRoom("scene3d", room3d);

        loadRoom("scene3d");
    }
    
    override void loadRoom(string name, bool deleteCurrent = false)
    {
        setCurrentRoom("loading", deleteCurrent);
        loading.reset(name);
    }
    
    ~this()
    {
        Delete(rm);
    }
    
    override void free()
    {
        Delete(this);
    }
}
