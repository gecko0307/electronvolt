module game.pause;

import dlib;
import dgl;
import game.app;

class PauseRoom: Room
{
    Layer layer2d;
    ScreenSprite pauseScreen;
    Texture pauseTex;

    this(EventManager em, GameApp app)
    {
        super(em, app);
        
        layer2d = addLayer(LayerType.Layer2D);

        pauseTex = app.rm.getTexture("ui/pause.png");
        
        pauseScreen = New!ScreenSprite(em, pauseTex);
        layer2d.addDrawable(pauseScreen);
    }
    
    override void onEnter()
    {
        eventManager.showCursor(true);
    }
    
    override void onKeyDown(int key)
    {
        if (key == SDLK_ESCAPE)
            app.exit();
        else if (key == SDLK_RETURN)
        {
            app.setCurrentRoom("scene3d");
        }
    }
    
    override void free()
    {
        Delete(this);
    }
}
