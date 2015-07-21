module kinematic;

import dlib;
import dmech;

/*
 * Kinematic controller implements an object that doesn't react to collisions 
 * with other bodies (like static body), yet is able to move and transfer its
 * movement to dynamic bodies - ideal for things like moving platforms.
 * Kinematic object's movement is fully controlled by the programmer.
 */
class KinematicController: Freeable
{
    PhysicsWorld world;
    RigidBody rbody;

    this(PhysicsWorld world, Vector3f pos, Geometry geom)
    {
        this.world = world;
        rbody = world.addStaticBody(pos);
        rbody.raycastable = true;
        world.addShapeComponent(rbody, geom, Vector3f(0, 0, 0), 1.0f);
    }

    void moveToPosition(Vector3f pos, double dt)
    {
        rbody.linearVelocity = (pos - rbody.position) / dt;
        rbody.position += rbody.linearVelocity * dt;
        rbody.updateShapeComponents();
    }

    void free()
    {
        Delete(this);
    }
}


