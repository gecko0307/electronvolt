module atrium.app;

import derelict.opengl.gl;

import dlib.math.vector;
import dlib.image.color;
import dlib.image.io.png;

import dgl.core.application;
import dgl.core.layer;
import dgl.core.event;
import dgl.core.drawable;
import dgl.vfs.vfs;
import dgl.templates.freeview;
import dgl.graphics.texture;
import dgl.ui.i18n;
import dgl.ui.ftfont;
import dgl.ui.textline;

import atrium.fpslayer;

class Crosshair: Drawable
{
    float width;
    float height;
    Vector2f position = Vector2f(0, 0);
    Texture tex;

    this(float w, float h, Vector2f position, Texture texture)
    {
        this.width = w;
        this.height = h;
        this.position = position;
        this.tex = texture;
    }

    override void draw(double dt)
    {
        glPushMatrix();
        glColor4f(1, 1, 1, 1);
        glTranslatef(position.x, position.y, 0.0f);
        tex.bind(dt);
        glDisable(GL_LIGHTING);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);
        glBegin(GL_QUADS);
        glTexCoord2f(0,0); glVertex2f(-width*0.5f, -height*0.5f);
        glTexCoord2f(0,1); glVertex2f(-width*0.5f, +height*0.5f);
        glTexCoord2f(1,1); glVertex2f(+width*0.5f, +height*0.5f);
        glTexCoord2f(1,0); glVertex2f(+width*0.5f, -height*0.5f);
        glEnd();
        tex.unbind();
        glEnable(GL_LIGHTING);
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_CULL_FACE);
        glPopMatrix();
    }

    override void free() {}
}

class GameApp: Application
{
    alias eventManager this;
    FreeTypeFont font;
    TextLine fpsText;

    FreeviewLayer layer3d;
    Layer layer2d;

    this()
    {
        super(800, 600, "Atrium");
        //clearColor = Color4f(0.025f, 0.05f, 0.1f);

        //layer3d = new FreeviewLayer(videoWidth, videoHeight, 1);
        //layer3d.alignToWindow = true;
        //addLayer(layer3d);
        
        // Comment this if using other camera
        //eventManager.setGlobal("camera", layer3d.camera);

        FPSLayer fpsLayer = new FPSLayer(videoWidth, videoHeight, 0, eventManager);
        //fpsLayer.addDrawable(new Axes());
        // Comment this if using other camera
        //fpsLayer.addModifier(layer3d.camera);
        addLayer(fpsLayer);

        layer2d = addLayer2D(-1);
        layer2d.alignToWindow = true;
        
        auto vfs = new VirtualFileSystem();
        vfs.mount("data/weapons");
        auto imgCrosshair = loadPNG(vfs.openForInput("crosshair.png"));
        auto texCrosshair = new Texture(imgCrosshair);
        Crosshair cs = new Crosshair(
            imgCrosshair.width, imgCrosshair.height, 
            Vector2f(videoWidth/2, videoHeight/2), texCrosshair);
        layer2d.addDrawable(cs);

        font = new FreeTypeFont("data/fonts/droid/DroidSans.ttf", 27);

        fpsText = new TextLine(font, localizef("FPS: %s", fps), Vector2f(10, 10));
        fpsText.alignment = Alignment.Left;
        fpsText.color = Color4f(1, 1, 1);
        layer2d.addDrawable(fpsText);
    }

    override void onQuit()
    {
        super.onQuit();
    }
    
    override void onKeyDown()
    {
        super.onKeyDown();
    }
    
    override void onMouseButtonDown()
    {
        super.onMouseButtonDown();
    }
    
    override void onUpdate()
    {
        super.onUpdate();
        fpsText.setText(localizef("FPS: %s", fps));
    }
}

