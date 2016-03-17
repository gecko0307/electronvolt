module game.kinematic;

import dlib.math.vector;
import dlib.math.quaternion;
import dmech.rigidbody;
import dmech.geometry;
import dmech.world;

/*
 * Kinematic controller implements an object that doesn't react to collisions 
 * with other bodies (like static body), yet is able to move and transfer its
 * movement to dynamic bodies - ideal for things like moving platforms.
 * Kinematic object's movement is fully controlled by the programmer.
 */
class KinematicController
{
    PhysicsWorld world;
    RigidBody rbody;
    Vector3f position;

    this(PhysicsWorld world, Vector3f pos, Geometry geom)
    {
        this.world = world;
        rbody = world.addStaticBody(pos);
        rbody.raycastable = true;
        world.addShapeComponent(rbody, geom, Vector3f(0, 0, 0), 1.0f);
        
        position = rbody.position;
    }

    void update(double dt)
    {
        rbody.linearVelocity = (position - rbody.position) / dt;
        rbody.position += rbody.linearVelocity * dt;

        rbody.orientation += 0.5f * Quaternionf(rbody.angularVelocity, 0.0f) * rbody.orientation * dt;
        rbody.orientation.normalize();

        rbody.updateShapeComponents();
    }
}


