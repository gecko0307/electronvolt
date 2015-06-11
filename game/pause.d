module game.pause;

import dlib;
import dgl;
import game.app;

class PauseRoom: Room
{
    Layer layer2d;
    ScreenSprite pauseScreen;
    Texture pauseTex;

    this(EventManager em, TestApp app)
    {
        super(em, app);
        
        layer2d = addLayer(LayerType.Layer2D);

        pauseTex = app.rm.getTexture("ui/pause.png");
        
        pauseScreen = New!ScreenSprite(em, pauseTex);
        layer2d.addDrawable(pauseScreen);
        
        //TextLineInput text = New!TextLineInput(em, app.rm.getFont("Droid"), Vector2f(10, em.windowHeight - 32));
        //layer2d.addDrawable(text);
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
            //eventManager.showCursor(false);
            app.setCurrentRoom("scene3d");
        }
    }
    
    override void free()
    {
        super.freeContent();
        Delete(this);
    }
}