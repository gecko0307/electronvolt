module cc;

import std.math;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.math.utils;

import dmech.world;
import dmech.rigidbody;
import dmech.geometry;
import dmech.shape;
import dmech.contact;
import dmech.raycast;

/*
 * CharacterController implements kinematic body
 * on top of dmech dynamics: it allows direct
 * velocity changes for a RigidBody.
 * CharacterController is intended for
 * generic action game character movement.
 */
class CharacterController
{
    PhysicsWorld world;
    RigidBody rbody;
    bool collidingWithFloor = false;
    bool onGround = false;
    bool falling = false;
    bool jumping = false;
    Vector3f direction = Vector3f(0, 0, 1);
    float speed = 0.0f;
    float maxVelocityChange = 0.75f;
    float artificalGravity = 50.0f;
    //Matrix4x4f localMatrix;
    Vector3f rotation;
    //Actor actor;

    this(PhysicsWorld world, Vector3f pos, float mass, Geometry geom = null)
    {
        this.world = world;
        rbody = world.addDynamicBody(pos);
        rbody.bounce = 0.0f;
        rbody.friction = 1.0f;
        rbody.enableRotation = false;
        rbody.useOwnGravity = true;
        rbody.gravity = Vector3f(0.0f, -artificalGravity, 0.0f);
        rbody.raycastable = false;
        //rbody.stopThreshold = 0.2f; 
        if (geom is null)
            geom = new GeomSphere(1.0f);
        world.addShapeComponent(rbody, geom, Vector3f(0, 0, 0), mass);
        //localMatrix = Matrix4x4f.identity;
        rotation = Vector3f(0, 0, 0);
        //worldGrav = world.gravity.length;

        rbody.onNewContact ~= (RigidBody b, Contact c)
        {
            if (dot((c.point - b.position).normalized, world.gravity.normalized) > 0.5f)
            //if (c.point.y <= b.position.y - 0.2f)
            //if (dot(-c.normal, world.gravity.normalized) > 0.3f)
            //if (abs(b.linearVelocity.y) < EPSILON)
            {
                collidingWithFloor = true;
            }
        };
    }
    
    /*
    void updateMatrix()
    {
        localMatrix = Matrix4x4f.identity;
        localMatrix *= rotationMatrix(Axis.x, degtorad(rotation.x));
        localMatrix *= rotationMatrix(Axis.y, degtorad(rotation.y));
        localMatrix *= rotationMatrix(Axis.z, degtorad(rotation.z));

        direction = localMatrix.forward;
    }
    */

    void update(bool clampY = true)
    {
        Vector3f targetVelocity = direction * speed;

        Vector3f velocityChange = targetVelocity - rbody.linearVelocity;
        velocityChange.x = clamp(velocityChange.x, -maxVelocityChange, maxVelocityChange);
        velocityChange.z = clamp(velocityChange.z, -maxVelocityChange, maxVelocityChange);
        if (clampY)
            velocityChange.y = 0;
        else
            velocityChange.y = clamp(velocityChange.y, -maxVelocityChange, maxVelocityChange);
        rbody.linearVelocity += velocityChange;

        speed = 0.0f;

        falling = rbody.linearVelocity.y < -0.05f;
        jumping = rbody.linearVelocity.y > 0.05f;

        if (abs(rbody.linearVelocity.y) > 2.0f)
            collidingWithFloor = false;

        onGround = checkOnGround() || collidingWithFloor;
    }

    bool checkOnGround()
    {
        CastResult cr;
        bool hit = world.raycast(rbody.position, Vector3f(0, -1, 0), 10, cr, true, true);
        if (hit)
        {
            if (distance(cr.point, rbody.position) <= 1.1f)
                return true;
        }
        return false;
    }

    void turn(float angle)
    {
        rotation.y += angle;
    }

    void move(Vector3f direction, float spd)
    {
        this.direction = direction;
        this.speed = spd;
    }

    void jump(float height)
    {
        //if (onGround || checkOnGround)
        if (onGround)
        {
            rbody.linearVelocity.y = jumpSpeed(height);
            collidingWithFloor = false;
        }
    }

    float jumpSpeed(float jumpHeight)
    {
        return sqrt(2.0f * jumpHeight * artificalGravity);
    }
}