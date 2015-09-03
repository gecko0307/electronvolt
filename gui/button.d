module gui.button;

import dlib;
import dgl;
import gui.widget;

class Button: Widget
{
    Color4f backgroundColor;
    
    this(EventManager emngr, Widget parentWidget)
    {
        super(emngr, parentWidget);
        position = Vector2f(0, 0);
        scale = Vector2f(20, 20);
        backgroundColor = Color4f(0.3f, 0.3f, 0.3f, 1.0f);
    }
    
    override void onClick(int button)
    {
    }
    
    override void draw(double dt)
    {
        glPushMatrix();
        glTranslatef(position.x, -position.y, 0);
        glScalef(scale.x, scale.y, 1);
        glColor4fv(backgroundColor.arrayof.ptr);
        glBegin(GL_QUADS);
        glVertex2f(0,  0);
        glVertex2f(0, -1);
        glVertex2f(1, -1);
        glVertex2f(1,  0);
        glEnd();
        glPopMatrix();
    }
    
    override void free()
    {
        Delete(this);
    }
}