module engine.physics2.world;

import std.stdio;

import dlib.math.vector;

import dlib.geometry.triangle;
import dlib.geometry.sphere;

import engine.physics2.geometry;
import engine.physics2.rigidbody;
import engine.physics2.collision;
import engine.physics2.mpr;
import engine.physics2.contact;
import engine.physics2.solver;
import engine.scene.bvh;

class PhysicsWorld
{
    RigidBody[] bodies;
    Vector3f gravity = Vector3f(0.0f, -9.81f, 0.0f);
    enum double fixedDelta = 1.0 / 60.0;
    
    RigidBody tmpTri;
    GeomTriangle tmpTriGeom;
    BVHNode bvhRoot = null;
    
    this()
    {
        tmpTri = new RigidBody();
        tmpTri.type = BodyType.Static;
        tmpTriGeom = new GeomTriangle(
            Vector3f(-1.0f, 0.0f, -1.0f), 
            Vector3f(+1.0f, 0.0f,  0.0f),
            Vector3f(-1.0f, 0.0f, +1.0f));
        tmpTri.setGeometry(tmpTriGeom);
        tmpTri.setMass(1000000.0f);
    }
    
    RigidBody addDynamicBody(Vector3f pos, float mass)
    {
        auto b = new RigidBody(pos);
        b.setMass(mass);
        b.type = BodyType.Dynamic;
        bodies ~= b;
        return b;
    }
    
    RigidBody addStaticBody(Vector3f pos)
    {
        auto b = new RigidBody(pos);
        b.setMass(1000000.0f);
        b.type = BodyType.Static;
        bodies ~= b;
        return b;
    }
    
    void update(double delta)
    {
        simulationStep(fixedDelta);
    }
    
    void simulationStep(double delta)
    {       
        if (bodies.length == 0)
            return;
        
        enum iterations = 10;
        delta /= iterations;
        
        foreach(b; bodies)
        {
            if (!b.disableGravity)
                b.applyForce(b.mass * gravity);
            b.onGround = false;
        }
               
        for(uint iteration = 0; iteration < iterations; iteration++)
        {
            foreach(b; bodies)
            {
                b.integrate(delta);
                b.updateGeomTransformation();
            }
         
            for (int i = 0; i < bodies.length - 1; i++)   
            for (int j = i + 1; j < bodies.length; j++)
            {
                Contact c;
                if (checkCollision(bodies[i], bodies[j], c))
                {
                    solveContact(c, iterations);
                    correctPositions(c);

                    Vector3f dirToContact = (c.point - bodies[i].position).normalized;
                    float groundness = dot(gravity.normalized, dirToContact);
                    if (groundness > 0.7f)
                        bodies[i].onGround = true;

                    dirToContact = (c.point - bodies[j].position).normalized;
                    groundness = dot(gravity.normalized, dirToContact);
                    if (groundness > 0.7f)
                        bodies[j].onGround = true;
                }
            }

            if (bvhRoot !is null)
            foreach(rb; bodies)
            {
                static Contact[5] contacts;
                static Triangle[5] contactTris;
                uint numContacts = 0;
                
                Sphere sphere;
                
                if (rb.type == BodyType.Dynamic)
                {
                    Contact c;
                    c.body1 = rb;
                    c.body2 = tmpTri;
                    c.fact = false;

                    //if (rb.geometry.type == GeomType.Sphere)
                    //{
                        //GeomSphere g1 = cast(GeomSphere)rb.geometry;
                        // TODO: get geometry bounding sphere
                        //sphere = Sphere(rb.geometry.position, 0.25f);
                        sphere = rb.geometry.boundingSphere;
                        
                        bvhRoot.traverseBySphere(sphere, (ref Triangle tri)
                        {
                            //tmpTriGeom.v = tri.v;
                            tmpTriGeom.transformation.translation = tri.barycenter;
                            tmpTriGeom.v[0] = tri.v[0] - tri.barycenter;
                            tmpTriGeom.v[1] = tri.v[1] - tri.barycenter;
                            tmpTriGeom.v[2] = tri.v[2] - tri.barycenter;

                            bool collided = MPRCollisionTest(rb.geometry, tmpTriGeom, c);
                
                            if (collided)
                            {                
                                if (numContacts < contacts.length)
                                {
                                    contacts[numContacts] = c;
                                    contactTris[numContacts] = tri;
                                    numContacts++;
                                }
                            }
                        });
                    //}
                }

                int deepestContactIdx = -1;
                float maxPen = 0.0f;
                float bestGroundness = -1.0f;
                foreach(i; 0..numContacts)
                {
                    if (contacts[i].penetration > maxPen)
                    {
                        deepestContactIdx = i;
                        maxPen = contacts[i].penetration;
                    }
                    
                    Vector3f dirToContact = (contacts[i].point - rb.position).normalized;
                    float groundness = dot(gravity.normalized, dirToContact);

                    if (groundness > 0.7f)
                        rb.onGround = true;
                }
 
                if (deepestContactIdx >= 0)
                {
                    //tmpTriGeom.tri = contactTris[deepestContactIdx];
                    auto tri = contactTris[deepestContactIdx];
                    tmpTri.position = tri.barycenter;
                
                    //solvePenetration(contacts[deepestContactIdx], penetrationSolverHardness);
                    //solveContact(contacts[deepestContactIdx], iterations, contactSolverHardness);

                    correctPositions(contacts[deepestContactIdx]);
                    solveContact(contacts[deepestContactIdx], iterations);
                }
            }
        }
        
        foreach(b; bodies)
            b.resetForces();
    }
}

