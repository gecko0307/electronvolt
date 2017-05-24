module game.physicsentity;

import std.stdio;
import dlib.math.vector;
import dlib.math.transformation;
import dgl.core.interfaces;
import dgl.graphics.entity;
import dmech.rigidbody;
import dmech.shape;
import dmech.contact;

class PhysicsEntity: Entity, CollisionDispatcher
{
    ShapeComponent shape;
    RigidBody rbody;
    
    this(Drawable d, RigidBody rb, uint shapeIndex = 0)
    {
        super(d);
       
        rbody = rb;
        
        if (rbody.shapes.length > shapeIndex)
        {
            shape = rbody.shapes[shapeIndex];
        }
        
        rbody.collisionDispatchers.append(this);
    }
    
    override Vector3f getPosition()
    {
        return transformation.translation;
    }
    
    void onHardCollision(float velProj)
    {
    }
    
    void onNewContact(RigidBody rb, Contact c)
    {        
        Vector3f rv = Vector3f(0.0f, 0.0f, 0.0f);
        rv += c.body1.linearVelocity + cross(c.body1.angularVelocity, c.body1RelPoint);
        rv -= c.body2.linearVelocity + cross(c.body2.angularVelocity, c.body2RelPoint);
        float vp = dot(rv, c.normal);
        if (vp < -2.0f)
        {
            onHardCollision(-vp);
        }
    }
    
    override void update(double dt)
    {
        if (shape !is null)
            transformation = shape.transformation;
        else
            super.update(dt);
    }
}
