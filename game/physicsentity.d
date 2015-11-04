module game.physicsentity;

import dlib;
import dgl;
import dmech;

class PhysicsEntity: Entity
{
    RigidBody rbody;
    ShapeComponent shape;
    Light light;
    bool highlight = false;
    
    this(Drawable d, RigidBody b, ShapeComponent s)
    {
        if (s)
            super(d, s.position);
        else
            super(d, Vector3f(0, 0, 0));
        rbody = b;
        shape = s;
    }
    
    override void draw(double dt)
    {
        if (shape !is null)
            transformation = shape.transformation;
        else
            transformation = Matrix4x4f.identity;
        // TODO: local transformation
        if (light)
            light.position = getPosition();
        super.draw(dt);
    }
    
    override void drawModel(double dt)
    {
        super.drawModel(dt);
    }
    
    override void free()
    {
        Delete(this);
    }
}