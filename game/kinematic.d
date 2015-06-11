module kinematic;

import dlib;
import dmech;

class KinematicObject: ManuallyAllocatable
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

    Vector3f p1 = Vector3f(10, 4, 0);
    Vector3f p2 = Vector3f(-3, 0.5f, 0);
    float t = 0.0f;
    int moveFwd = 1;
    void update(double dt)
    {
        t += 0.1f * dt * moveFwd;
        if (t >= 1.0f) { moveFwd = -1; }
        else if (t <= 0.0f) { moveFwd = +1; }

        Vector3f newPosition = lerp(p1, p2, t);
        rbody.linearVelocity = (newPosition - rbody.position) / dt;
        rbody.position += rbody.linearVelocity * dt;
        rbody.updateShapeComponents();
    }

    mixin FreeImpl;
    mixin ManualModeImpl;
}