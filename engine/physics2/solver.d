module engine.physics2.solver;

import std.math;
import std.algorithm;

import dlib.math.vector;
import dlib.math.utils;

import engine.physics2.rigidbody;
import engine.physics2.contact;

void solveContact(Contact c, uint iterations)
{
    RigidBody body1 = c.body1;
    RigidBody body2 = c.body2;
    
    Vector3f r1 = c.point - body1.position;
    Vector3f r2 = c.point - body2.position;
    
    Vector3f relativeVelocity = Vector3f(0.0f, 0.0f, 0.0f);

    relativeVelocity += body1.linearVelocity + cross(body1.angularVelocity, r1);
    relativeVelocity -= body2.linearVelocity + cross(body2.angularVelocity, r2);
    
    float velocityProjection = dot(relativeVelocity, c.normal);
    
    // Check if the bodies are already moving apart
    if (velocityProjection > 0.0f)
        return;
    
    // Calculate normal impulse
    Vector3f n1 = c.normal;
    Vector3f w1 = c.normal.cross(r1);
    Vector3f n2 = -c.normal;
    Vector3f w2 = -(c.normal.cross(r2));
    
    float bounce = 0.4f; //c.restitution
    float a = velocityProjection; // * (1 + bounce);

    //float deltaVelocity = 0.001f;
    //a = a - deltaVelocity;
    //if (a < 0.0f)
    //    a = 0.0f;
    //float a = max(0, velocityProjection * (1 + bounce) - deltaVelocity);

    a *= iterations;
 
    float b = n1.dot(n1) * body1.invMass
            + w1.dot(w1) * body1.invInertiaMoment
            + n2.dot(n2) * body2.invMass 
            + w2.dot(w2) * body2.invInertiaMoment;
    
    float impulse = (-a / b);
    
    if (impulse < 0.05f)
        return;

    //impulse *= 0.9f;
    //impulse /= iterations;

    //float staticFriction = 0.2f;
    //float dynamicFriction = 0.2f;

    float normalImpulse = impulse;

    float hardness = 0.9f;

    //float mu = 0.5f;
    //float frictionImpulse = mu * fabs(impulse);
    //Vector3f tangentRelVel = relativeVelocity - dot(relativeVelocity, c.normal) * c.normal;
    //Vector3f dirRelVel = tangentRelVel.normalized;
    //Rvector tangentRelVelAfter = tangentRelVel - dirRelVel * frictionImpulse * c.body1.invMass;
    
    float staticFriction = 0.9f;
    float dynamicFriction = 0.9f;

    // Calculate tangent (friction) impulse
    Vector3f tangent = Vector3f(0.0f, 0.0f, 0.0f);
    float tangentSpeed = 0.0f;

    if (velocityProjection != 0.0f)
    {
        Vector3f VonN = relativeVelocity - dot(relativeVelocity, c.normal) * c.normal;
        tangentSpeed = VonN.length;
        if (tangentSpeed > 0)
            tangent = -VonN * (1.0f / tangentSpeed);
    }

    if (tangentSpeed != 0.0f)
    {
        float denom = body1.invMass + body2.invMass;
        
        denom += dot(cross(body1.invInertiaMoment * cross(r1, tangent), r1), tangent);
        denom += dot(cross(body2.invInertiaMoment * cross(r2, tangent), r2), tangent);
        
        float desiredImpulse = tangentSpeed / denom;
        
        float impulseToReverse = desiredImpulse;
        float impulseFromNormalImpulse = impulse * staticFriction;
        
        float frictionImpulse; 
        if (impulseToReverse < impulseFromNormalImpulse)
             frictionImpulse = impulseToReverse;
        else
             frictionImpulse = impulse * dynamicFriction;

        tangent *= frictionImpulse;
    }

    // Apply impulse to bodies
    Vector3f impulseVec = impulse * c.normal + tangent;
    impulseVec /= iterations;
    //impulseVec *= 0.9f;
    
    if (body1.type == BodyType.Dynamic) 
        body1.applyImpulseAtPoint(+impulseVec, c.point);
    if (body2.type == BodyType.Dynamic) 
        body2.applyImpulseAtPoint(-impulseVec, c.point);

/*
    // Friction
    if (body1.type == BodyType.Dynamic)
    {
        Vector3f colPointVelRelNew = c.body1.linearVelocity + c.body1.angularVelocity.cross(r1);
        Vector3f tangentVel = colPointVelRelNew - (c.normal * colPointVelRelNew.dot(c.normal));
        float tangentSpeed = tangentVel.length;
        Vector3f tVec = -tangentVel * (1.0f / tangentSpeed);
        Vector3f r1CrossColTangent = r1.cross(tVec);
        r1CrossColTangent = r1CrossColTangent * c.body1.invInertiaMoment;
        float denominator = c.body1.invMass + tVec.dot(r1CrossColTangent * r1);
        if (denominator > EPSILON)
        {
            float impulseToReverse = tangentSpeed / denominator;
            float impulseFromNormalImpulse = normalImpulse * staticFriction;

            float frictionImpulse;  
            if (impulseToReverse < impulseFromNormalImpulse)
                frictionImpulse = impulseToReverse;
            else
                frictionImpulse = normalImpulse * dynamicFriction;

            tVec *= frictionImpulse;
        }
        else tVec = Vector3f(0.0f, 0.0f, 0.0f);

        Vector3f impulseVec = impulse * c.normal + tVec;
        impulseVec /= iterations;
        impulseVec *= hardness;

        body1.applyImpulseAtPoint(impulseVec, c.point);
    }

    if (body2.type == BodyType.Dynamic)
    {
        Vector3f colPointVelRelNew = c.body2.linearVelocity + c.body2.angularVelocity.cross(r2);
        Vector3f tangentVel = colPointVelRelNew - (-c.normal * colPointVelRelNew.dot(-c.normal));
        float tangentSpeed = tangentVel.length;
        Vector3f tVec = -tangentVel * (1.0f / tangentSpeed);
        Vector3f r2CrossColTangent = r2.cross(tVec);
        r2CrossColTangent = r2CrossColTangent * c.body2.invInertiaMoment;
        float denominator = c.body2.invMass + tVec.dot(r2CrossColTangent * r2);
        if (denominator > EPSILON)
        {
            float impulseToReverse = tangentSpeed / denominator;
            float impulseFromNormalImpulse = normalImpulse * staticFriction;

            float frictionImpulse;  
            if (impulseToReverse < impulseFromNormalImpulse)
                frictionImpulse = impulseToReverse;
            else
                frictionImpulse = normalImpulse * dynamicFriction;

            tVec *= frictionImpulse;
        }
        else tVec = Vector3f(0.0f, 0.0f, 0.0f);

        Vector3f impulseVec = impulse * -c.normal + tVec;
        impulseVec /= iterations;
        impulseVec *= hardness;

        body2.applyImpulseAtPoint(impulseVec, c.point);
    }
*/
}

void correctPositions(Contact c)
{
    RigidBody body1 = c.body1;
    RigidBody body2 = c.body2;

    float hardness = 1.0f; //0.95f;

    if (c.body1.type == BodyType.Dynamic && 
        c.body2.type == BodyType.Dynamic)
    {
        Vector3f b1trans = c.normal * c.penetration * 0.5f;
        c.body1.position += b1trans * hardness;
        
        Vector3f b2trans = (-c.normal) * c.penetration * 0.5f;
        c.body2.position += b2trans * hardness;
    }
    else if (c.body1.type == BodyType.Dynamic)
    {
        Vector3f b1trans = c.normal * c.penetration;
        c.body1.position += b1trans * hardness;
    }
    else if (c.body2.type == BodyType.Dynamic)
    {
        Vector3f b2trans = (-c.normal) * c.penetration;
        c.body2.position += b2trans * hardness;
    }
}

void correctPositions2(Contact c)
{
    RigidBody body1 = c.body1;
    RigidBody body2 = c.body2;

    float invMass = body1.invMass + body2.invMass;
    Vector3f movePerIMass = c.normal * (c.penetration / invMass);
    
    if (body1.type == BodyType.Dynamic) 
        body1.position += movePerIMass * body1.invMass;
    if (body2.type == BodyType.Dynamic) 
        body2.position -= movePerIMass * body2.invMass;
}

