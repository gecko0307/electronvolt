module engine.physics2.rigidbody;

import std.math;

import dlib.math.vector;
import dlib.math.quaternion;
import dlib.math.matrix4x4;
import dlib.math.matrix3x3;

import engine.physics2.geometry;
import engine.physics2.contact;

enum BodyType
{
    Static,
    Dynamic,
    Kinematic
}

class RigidBody
{
    //bool dynamic = true;
    BodyType type = BodyType.Dynamic;
    
    Vector3f position;
    Vector3f linearVelocity;

    Quaternionf orientation;
    Vector3f angularVelocity;

    float mass = 1.0f;
    float inertiaMoment = 1.0f;
    
    float invMass = 1.0f;
    float invInertiaMoment = 1.0f;
    
    float dampingFactor = 0.999f;
    //Vector3f dampingVector = Vector3f(0.999f, 0.0f, 0.999f);

    Vector3f forceAccumulator;
    Vector3f torqueAccumulator;

    Geometry geometry;
    
    bool disableRotation = false;
    bool disableGravity = false;
    
    Vector3f gravityDirection;
    Contact lastGroundContact;

    bool onGround = false;
    
    this(Vector3f pos = Vector3f(0.0f, 0.0f, 0.0f))
    {
        position = pos;
        linearVelocity = Vector3f(0.0f, 0.0f, 0.0f);

        orientation = Quaternionf(0.0f, 0.0f, 0.0f, 1.0f);
        angularVelocity = Vector3f(0.0f, 0.0f, 0.0f);

        forceAccumulator = Vector3f(0.0f, 0.0f, 0.0f);
        torqueAccumulator = Vector3f(0.0f, 0.0f, 0.0f);
    }
    
    void setGeometry(Geometry geom)
    {
        geometry = geom;
        setMass(mass);
    }
    
    void setMass(float m)
    {
        mass = m;       
        invMass = 1.0f / mass;
        
        if (geometry !is null)
        {
            inertiaMoment = geometry.inertiaMoment(mass);
            invInertiaMoment = 1.0f / inertiaMoment;
        }
    }
    
    void integrate(double delta)
    {
        if (type == BodyType.Dynamic)
        {
            Vector3f acceleration;

            acceleration = forceAccumulator * invMass;
            linearVelocity += acceleration * delta;

            acceleration = torqueAccumulator * invInertiaMoment;
            angularVelocity += acceleration * delta;

            //linearVelocity.x *= dampingFactor;
            //linearVelocity.z *= dampingFactor;
            
            linearVelocity *= dampingFactor;
            angularVelocity *= dampingFactor;
            
            /*
            enum float linearVelEpsilon = 0.001f;
            enum float angularVelEpsilon = 0.05f;
            if (linearVelocity.length < linearVelEpsilon)
                linearVelocity = Vector3f(0.0f, 0.0f, 0.0f);
            if (angularVelocity.length < angularVelEpsilon)
                angularVelocity = Vector3f(0.0f, 0.0f, 0.0f);
            */
            
            //linearVelocity *= pow(linearDamping, delta);
            //angularVelocity *= pow(angularDamping, delta);
            
            position += linearVelocity * delta;
            
            orientation += 0.5f * Quaternionf(angularVelocity, 0.0f) * orientation * delta;
            orientation.normalize();
        }
    }
       
    void updateGeomTransformation()
    {
        if (geometry !is null)
        {
            if (disableRotation)
                geometry.setTransformation(position, Quaternionf(0.0f, 0.0f, 0.0f, 1.0f));
            else
                geometry.setTransformation(position, orientation);
        }
    }
    
    void resetForces()
    {
        forceAccumulator = Vector3f(0.0f, 0.0f, 0.0f);
        torqueAccumulator = Vector3f(0.0f, 0.0f, 0.0f);
    }
    
    void applyForce(Vector3f force)
    {
        forceAccumulator += force;
    }
    
    void applyTorque(Vector3f torque)
    {
        if (!disableRotation)
            torqueAccumulator += torque;
    }
    
    void applyForceAtPoint(Vector3f force, Vector3f point)
    {
        forceAccumulator += force;
        if (!disableRotation)
            //Vector3f torque = cross(point - position, force);
            torqueAccumulator += cross(point - position, force);
    }
    
    void applyForceAtLocalPoint(Vector3f force, Vector3f point)
    {
        forceAccumulator += force;
        if (!disableRotation)
            //Vector3f torque = cross(point, force);
            torqueAccumulator += cross(point, force);
    }
    
    void applyImpulse(Vector3f impulse)
    {
        linearVelocity += impulse * invMass;
    }
    
    void applyAngularImpulse(Vector3f angularImpulse)
    {
        if (!disableRotation)
            angularVelocity += angularImpulse * invInertiaMoment;
    }
    
    void applyImpulseAtPoint(Vector3f impulse, Vector3f point)
    {
        linearVelocity += impulse * invMass;
        
        if (!disableRotation)
        {
            Vector3f angularImpulse = cross(point - position, impulse);
            angularVelocity += angularImpulse * invInertiaMoment;
        }
    }
    
    void applyImpulseAtLocalPoint(Vector3f impulse, Vector3f point)
    {
        linearVelocity += impulse * invMass;
        
        if (!disableRotation)
        {
            Vector3f angularImpulse = cross(point, impulse);
            angularVelocity += angularImpulse * invInertiaMoment;
        }
    }
}

