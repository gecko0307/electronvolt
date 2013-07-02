module engine.physics2.contact;

import dlib.math.vector;
import engine.physics2.rigidbody;

struct Contact
{
    RigidBody body1;
    RigidBody body2;
    
    bool fact;

    Vector3f point;
    Vector3f normal;
    float penetration;
    
    float friction = 0.8f;
    float restitution = 0.5f;
}