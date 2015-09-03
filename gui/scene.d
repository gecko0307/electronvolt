module gui.scene;

import dlib;
import dgl;
import gui.gizmo;

class EditorScene: EventListener, Drawable
{
    DynamicArray!Entity entities;
    Gizmo gizmo;
    
    this(EventManager emngr)
    {
        super(emngr);
        gizmo = New!Gizmo(eventManager);
    }
    
    ~this()
    {
        foreach(e; entities.data)
            e.free();
        entities.free();
        gizmo.free();
    }
    
    void onUpdate()
    {
        processEvents();
    }
    
    void addEntity(Entity e)
    {
        entities.append(e);
    }
    
    override void draw(double dt)
    {
        foreach(e; entities.data)
            e.draw(dt);

        if (gizmo.entity)
        {
            glDisable(GL_DEPTH_TEST);
            glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
            glDisable(GL_LIGHTING);
            gizmo.entity.draw(dt);
            glEnable(GL_LIGHTING);
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
            gizmo.draw(dt);
            glEnable(GL_DEPTH_TEST);
        }
    }
    
    override void free()
    {
        Delete(this);
    }
}