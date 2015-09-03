module gui.gizmo;

import std.math;
import dlib;
import dgl;
import gui.scene;

class Gizmo: EventListener, Drawable
{
    Vector3f position;
    Ray ray;
    bool snap = true;
    int highlightedAxis = 0;
    float axisWidth = 0.2f;
    Entity entity;

    this(EventManager emngr)
    {
        super(emngr);
        position = Vector3f(0, 0, 0);
        ray = Ray(Vector3f(0, 0, 0), Vector3f(0, 0, 1));
    }
    
    void translate(Vector3f trans)
    {
        if (snap)
            position += Vector3f(floor(trans.x), floor(trans.y), floor(trans.z));
        else
            position += trans;
    }
    
    void applyTranformationTo(Entity e)
    {
        e.setTransformation(position, Quaternionf.identity, e.scaling);
    }
    
    bool pickAxis(Ray r, out Vector3f axis, out Vector3f ip)
    {
        AABB axisXbb = AABB(position + Vector3f(0.5f, 0.0f, 0.0f), Vector3f(0.5f, axisWidth, axisWidth));
        AABB axisYbb = AABB(position + Vector3f(0.0f, 0.5f, 0.0f), Vector3f(axisWidth, 0.5f, axisWidth));
        AABB axisZbb = AABB(position + Vector3f(0.0f, 0.0f, 0.5f), Vector3f(axisWidth, axisWidth, 0.5f));
        float t;
        if (axisXbb.intersectsSegment(r.p0, r.p1, t))
        {
            axis = Vector3f(1, 0, 0);
            ip = (r.p1 - r.p0).normalized * t;
            return true;
        }
        else if (axisYbb.intersectsSegment(r.p0, r.p1, t))
        {
            axis = Vector3f(0, 1, 0);
            ip = (r.p1 - r.p0).normalized * t;
            return true;
        }
        else if (axisZbb.intersectsSegment(r.p0, r.p1, t))
        {
            axis = Vector3f(0, 0, 1);
            ip = (r.p1 - r.p0).normalized * t;
            return true;
        }
        else
            return false;
    }

    override void draw(double dt)
    {
        if (entity)
        {
            position = entity.position;
        }
    
        glPushMatrix();
        glTranslatef(position.x, position.y, position.z);
        glDisable(GL_LIGHTING);
        glDisable(GL_DEPTH_TEST);
        glPointSize(5.0f);
        glPushMatrix();
        glScalef(1.0f, 1.0f, 1.0f);
        glColor3f(1.0f, 1.0f, 1.0f);
        if (highlightedAxis != 1) glColor3f(1.0f, 0.0f, 0.0f);
        glBegin(GL_LINES);
        glVertex3f(0.0f, 0.0f, 0.0f);
        glVertex3f(1.0f, 0.0f, 0.0f);
        glEnd();
        glBegin(GL_POINTS);
        glVertex3f(1.0f, 0.0f, 0.0f);
        glEnd();
        glColor3f(1.0f, 1.0f, 1.0f);
        if (highlightedAxis != 2) glColor3f(0.0f, 1.0f, 0.0f);
        glBegin(GL_LINES);
        glVertex3f(0.0f, 0.0f, 0.0f);
        glVertex3f(0.0f, 1.0f, 0.0f);
        glEnd();
        glBegin(GL_POINTS);
        glVertex3f(0.0f, 1.0f, 0.0f);
        glEnd();
        glColor3f(1.0f, 1.0f, 1.0f);
        if (highlightedAxis != 3) glColor3f(0.0f, 0.0f, 1.0f);
        glBegin(GL_LINES);
        glVertex3f(0.0f, 0.0f, 0.0f);
        glVertex3f(0.0f, 0.0f, 1.0f);
        glEnd();
        glBegin(GL_POINTS);
        glVertex3f(0.0f, 0.0f, 1.0f);
        glEnd();
        glColor3f(1.0f, 1.0f, 1.0f);
        glBegin(GL_POINTS);
        glVertex3f(0.0f, 0.0f, 0.0f);
        glEnd();
        glPopMatrix();
        glPointSize(1.0f);
        glPopMatrix();
/*        
        glBegin(GL_LINES);
        glVertex3fv(ray.p0.arrayof.ptr);
        glVertex3fv(ray.p1.arrayof.ptr);
        glEnd();
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_LIGHTING);
*/
    }
    
    override void free()
    {
        Delete(this);
    }
}