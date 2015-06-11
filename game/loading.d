module game.loading;

import dlib;
import dgl;
import game.app;

class LoadingRoom: Room
{
    Layer layer2d;
    ScreenSprite loadingScreen;
    Texture loadingTex;
    string nextRoomName;
    double counter = 0.0;
    
    this(EventManager em, TestApp app)
    {
        super(em, app);        
        layer2d = addLayer(LayerType.Layer2D);
        
        loadingTex = app.rm.getTexture("ui/loading.png");
        
        loadingScreen = New!ScreenSprite(em, loadingTex);
        layer2d.addDrawable(loadingScreen);
    }
    
    void reset(string name)
    {
        nextRoomName = name;
        counter = 0.5;
    }
    
    override void onEnter()
    {
        eventManager.showCursor(true);
    }
    
    override void onUpdate()
    {
        super.onUpdate();
        counter -= eventManager.deltaTime;
        
        if (counter <= 0.0)
        {
            counter = 0.0;
            app.setCurrentRoom(nextRoomName, false);
        }
    }
    
    override void free()
    {
        super.freeContent();
        Delete(this);
    }
}