module game.physicsentity;

import dlib.math.vector;
import dlib.math.affine;
import dgl.core.interfaces;
import dgl.graphics.entity;
import dmech.rigidbody;
import dmech.shape;

class PhysicsEntity: Entity
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
    }
    
    override Vector3f getPosition()
    {
        return transformation.translation;
    }
    
    override void update(double dt)
    {
        if (shape !is null)
            transformation = shape.transformation;
        else
            super.update(dt);
    }
}