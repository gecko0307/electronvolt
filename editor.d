module main;

import std.stdio;
import std.algorithm;
import dlib;
import dgl;
import gui.window;
import gui.widget;
import gui.scene;
import gui.sceneview;

class Grid: Drawable
{
    float cellWidth = 1.0f;
    int size = 20;
    
    override void draw(double dt)
    {
        glColor4f(1, 1, 1, 0.25f);
        foreach(x; 0..size+1)
        {
            glBegin(GL_LINES);
            glVertex3f((x - size/2) * cellWidth, 0, -size/2);
            glVertex3f((x - size/2) * cellWidth, 0,  size/2);
            glEnd();
        }
        
        foreach(y; 0..size+1)
        {
            glBegin(GL_LINES);
            glVertex3f(-size/2, 0, (y - size/2) * cellWidth);
            glVertex3f( size/2, 0, (y - size/2) * cellWidth);
            glEnd();
        }
        glColor4f(1, 1, 1, 1);
    }

    override void free()
    {
        Delete(this);
    }
}

class EditorApp: Application
{
    WindowManager wm;
    SceneView sv;
    EditorScene scene;
    ShapeBox ss;

    this()
    {
        super(800, 600, "DGLEditor");
        exitOnEscapePress = false;
        clearColor = Color4f(0.5f, 0.5f, 0.5f);
        wm = New!WindowManager(eventManager);
        wm.addWindow(Vector2f(0, 0), Vector2f(100, 100));
        wm.addWindow(Vector2f(50, 50), Vector2f(100, 100));
        
        scene = New!EditorScene(eventManager);
        ss = New!ShapeBox(Vector3f(1,1,1));
        scene.addEntity(New!Entity(ss, Vector3f(0, 0, 0)));
        scene.addEntity(New!Entity(ss, Vector3f(2, 0, 0)));
        
        auto w = wm.addWindow(Vector2f(100, 100), Vector2f(320, 240));
        sv = New!SceneView(eventManager, w);
        w.addWidget(sv);
        sv.scene = scene;
        sv.addDrawable(New!Grid());
        
        w = wm.addWindow(Vector2f(50, 50), Vector2f(320, 240));
        auto sv2 = New!SceneView(eventManager, w);
        w.addWidget(sv2);
        sv2.scene = scene;
        sv2.addDrawable(New!Grid());
        //sv2.addEntity(eSphere);
    }
    
    ~this()
    {
        Delete(wm);
        Delete(scene);
        Delete(ss);
    }
    
    override void onKeyDown(int key)
    {
        if (key == 'a')
            scene.addEntity(New!Entity(ss, Vector3f(0, 0, 0)));
    }
    
    override void free()
    {
        Delete(this);
    }
    
    override void onUpdate()
    {
        wm.onUpdate();
    }
    
    override void onRedraw()
    {
        double dt = eventManager.deltaTime;
        wm.draw(dt);
    }
}

void main(string[] args)
{
    loadLibraries();

    writefln("Allocated memory at start: %s", allocatedMemory);
    auto app = New!EditorApp();
    app.run();
    Delete(app);
    writefln("Allocated memory at end: %s", allocatedMemory);
    //printMemoryLog();
}
