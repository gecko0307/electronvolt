module game.character;

import std.math;

import dlib.core.memory;
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
class CharacterController: Freeable //, CollisionDispatcher
{
    PhysicsWorld world;
    RigidBody rbody;
    bool collidingWithFloor = false;
    bool onGround = false;
    bool falling = false;
    bool jumping = false;
    Vector3f direction = Vector3f(0, 0, 1);
    float speed = 0.0f;
    float jSpeed = 0.0f;
    float maxVelocityChange = 0.75f;
    float artificalGravity = 50.0f;
    Vector3f rotation;
	float newContactSlopeFactor = 1.0f;
    RigidBody floorBody;
    bool flyMode = false;

    this(PhysicsWorld world, Vector3f pos, float mass, Geometry geom)
    {
        this.world = world;
        rbody = world.addDynamicBody(pos);
        rbody.bounce = 0.0f;
        rbody.friction = 1.0f;
        rbody.enableRotation = false;
        rbody.useOwnGravity = true;
        rbody.gravity = Vector3f(0.0f, -artificalGravity, 0.0f);
        rbody.raycastable = false;
        world.addShapeComponent(rbody, geom, Vector3f(0, 0, 0), mass);
        rotation = Vector3f(0, 0, 0);

        //rbody.collisionDispatchers.append(this);
    }
    
    void enableGravity(bool mode)
    {
        flyMode = !mode;
        
        if (mode)
        {
            rbody.gravity = Vector3f(0.0f, -artificalGravity, 0.0f);
        }
        else
        {
            rbody.gravity = Vector3f(0, 0, 0);
        }
    }

    void onNewContact(RigidBody b, Contact c)
    {
    /*
        // FIXME
	    newContactSlopeFactor = dot((c.point - b.position).normalized, world.gravity.normalized);
        if (newContactSlopeFactor > 0.0f)
        {
            collidingWithFloor = true;
        }
    */
    }

    void update(bool clampY = true)
    {
        Vector3f targetVelocity = direction * speed;

        Vector3f velocityChange = targetVelocity - rbody.linearVelocity;
        velocityChange.x = clamp(velocityChange.x, -maxVelocityChange, maxVelocityChange);
        velocityChange.z = clamp(velocityChange.z, -maxVelocityChange, maxVelocityChange);
        if (clampY && !flyMode)
            velocityChange.y = 0;
        else
            velocityChange.y = clamp(velocityChange.y, -maxVelocityChange, maxVelocityChange);
        rbody.linearVelocity += velocityChange;

        falling = rbody.linearVelocity.y < -0.05f;
        jumping = rbody.linearVelocity.y > 0.05f;

        if (abs(rbody.linearVelocity.y) > 2.0f)
            collidingWithFloor = false;

        onGround = checkOnGround() || collidingWithFloor;

        if (onGround && floorBody && speed == 0.0f && jSpeed == 0.0f)
            rbody.linearVelocity = floorBody.linearVelocity;
        if (!flyMode)
        {
            speed = 0.0f;
            jSpeed = 0.0f;
        }
        else
        {
            speed *= 0.95f;
            jSpeed *= 0.95f;
        }
    }

    bool checkOnGround()
    {
        floorBody = null;
        CastResult cr;
        bool hit = world.raycast(rbody.position, Vector3f(0, -1, 0), 10, cr, true, true);
        if (hit)
        {
            if (distance(cr.point, rbody.position) <= 1.1f) //1.1f
            {
                floorBody = cr.rbody;
                return true;
            }
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
        if (onGround || flyMode)
        {
            jSpeed = jumpSpeed(height);
            rbody.linearVelocity.y = jSpeed;
            collidingWithFloor = false;
        }
    }

    float jumpSpeed(float jumpHeight)
    {
        return sqrt(2.0f * jumpHeight * artificalGravity);
    }

    override void free()
    {
        Delete(this);
    }
}
