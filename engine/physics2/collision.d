module engine.physics2.collision;

import std.math;
import dlib.math.vector;
import dlib.math.matrix4x4;

import engine.physics2.geometry;
import engine.physics2.rigidbody;
import engine.physics2.contact;
import engine.physics2.colfuncs;
import engine.physics2.mpr;

bool checkCollision(RigidBody body1, RigidBody body2, ref Contact c)
{
    c.body1 = body1;
    c.body2 = body2;
        
    bool collided = false;
        
    if (c.body1.geometry.type == GeomType.Sphere)
    {
        GeomSphere g1 = cast(GeomSphere)body1.geometry;
        
        if (c.body2.geometry.type == GeomType.Sphere)
        {
            GeomSphere g2 = cast(GeomSphere)body2.geometry;
            collided = checkCollisionSphereVsSphere(g1, g2, c);
        }
        else if (c.body2.geometry.type == GeomType.Box)
        {
            GeomBox g2 = cast(GeomBox)body2.geometry;
            collided = checkCollisionSphereVsBox(g1, g2, c);
        }
        else
        {
            collided = MPRCollisionTest(body1.geometry, body2.geometry, c);
        }
    }
    else if (c.body1.geometry.type == GeomType.Box)
    {
        GeomBox g1 = cast(GeomBox)body1.geometry;
        
        if (c.body2.geometry.type == GeomType.Sphere)
        {
            GeomSphere g2 = cast(GeomSphere)body2.geometry;
            collided = checkCollisionSphereVsBox(g2, g1, c);
            c.normal = -c.normal;
        }
        else
        {
            collided = MPRCollisionTest(body1.geometry, body2.geometry, c);
        }
    }
    else
    {
        collided = MPRCollisionTest(body1.geometry, body2.geometry, c);
    }
    
    if (collided)
        c.fact = true;
        
    return collided;
}

