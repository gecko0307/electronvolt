module game.particles;

import std.math;
import std.random;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.interpolation;
import dlib.image.color;

import dgl.core.api;
import dgl.core.interfaces;

import dmech.world;
import dmech.rigidbody;
import dmech.raycast;

struct Particle
{
    Vector3f position;
    Vector3f velocity;
    Vector3f gravityVector;
    float lifetime;
    float time;
    bool move;
    RigidBody colBody;
}

class ParticleSystem: Drawable
{
    PhysicsWorld world;
    Vector3f source;

    Particle[] particles;

    float minLifetime = 0.5f;
    float maxLifetime = 2.0f;

    bool animateColor = true;
    bool drawTrails = true;
    Color4f primaryColor = Color4f(1, 1, 1, 1);
    Color4f secondaryColor = Color4f(1, 1, 1, 0);

    //Vector3f gravityVector = Vector3f(0, -1, 0);
    bool collisions = false;
    float airFrictionDamping = 0.95f;
    float collisionDamping = 0.8f;
    float startSpeed = 20.0f;
    float startVelRandomRadius = 1.0f;
    
    bool haveParticlesToDraw = false;
    
    this(PhysicsWorld world, Vector3f src, uint num = 15)
    {
        this.world = world;
        source = src;
        particles = New!(Particle[])(num);
        foreach(ref p; particles)
        {
            p.position = source;
            Vector3f vDir = Vector3f(0, 1, 0);
            p.velocity = randomizeDirection(vDir) * startSpeed;
            p.lifetime = uniform(minLifetime, maxLifetime);
            p.gravityVector = Vector3f(0, -1, 0);
            p.time = p.lifetime;
            p.move = false;
        }
    }
    
    void reset(Vector3f src, Vector3f dir)
    {
        source = src;
        foreach(ref p; particles)
        {
            p.position = source;
            p.velocity = randomizeDirection(dir) * startSpeed;
            p.lifetime = uniform(minLifetime, maxLifetime);
            p.gravityVector = Vector3f(0, -1, 0);
            p.time = 0.0f;
            p.move = true;
        }
    }

    Vector3f randomizeDirection(Vector3f dir)
    {
        dir.normalize();
        float x = uniform(-startVelRandomRadius, startVelRandomRadius);
        float y = uniform(-startVelRandomRadius, startVelRandomRadius);
        Vector3f n0, n1;
        n0 = cross(randomUnitVector3!float, dir);
        n1 = cross(n0, dir);
        n0.normalize();
        n1.normalize();

        dir += n0 * x + n1 * y;
        dir.normalize();
        return dir;
    }
    
    void update(double dt)
    {
        haveParticlesToDraw = false;
    
        foreach(ref p; particles)
        if (p.time < p.lifetime)
        {
            p.time += dt;
            if (p.move)
            {
                p.velocity += p.gravityVector;
                p.velocity = p.velocity * airFrictionDamping;
                p.position += p.velocity * dt;
                if (collisions)
                    particleCollisions(p);
            }
            
            haveParticlesToDraw = true;
        }
    }
    
    void particleCollisions(ref Particle p)
    {
        CastResult cr;
        bool isec = world.raycast(p.position, p.velocity.normalized, 10.0f, cr, true, true);
        if (isec && cr.param < 0.2f)
        {
            p.velocity = reflect(p.velocity, cr.normal) * collisionDamping;
            p.colBody = cr.rbody;
            if (p.velocity.length < 1.0f && 
                !cr.rbody.dynamic && 
                dot(cr.normal, -p.gravityVector) > 0.5f)
            {
                p.move = false;
                p.position = cr.point;
            }
        }
    }
    
    Vector3f reflect(Vector3f v, Vector3f n)
    {
        return n * -2.0f * dot(v, n) + v;
    }
    
    void draw(double dt)
    {
        if (!haveParticlesToDraw)
        {
            return;
        }
    
        glDisable(GL_LIGHTING);
        glLineWidth(5.0f);
        glPointSize(5.0f);
        glEnable(GL_ALPHA_TEST);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        glDepthMask(GL_FALSE);

        foreach(ref p; particles)
        if (p.time < p.lifetime)
        {
            Color4f col = primaryColor;
            if (animateColor)
            {
                float t = p.time / p.lifetime;
                col = lerp(primaryColor, secondaryColor, t);
            }
            
            if (p.move && drawTrails)
            {
                Vector3f endPoint = p.position - p.velocity * 0.04f;
                glBegin(GL_LINES);
                glColor4fv(col.arrayof.ptr);
                glVertex3fv(p.position.arrayof.ptr);
                glColor4f(col.r, col.g, col.b, 0);
                glVertex3fv(endPoint.arrayof.ptr);
                glEnd();
            }
            else
            {
                glBegin(GL_POINTS);
                glColor4fv(col.arrayof.ptr);
                glVertex3fv(p.position.arrayof.ptr);
                glEnd();
            }
        }

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDepthMask(GL_TRUE);
        glLineWidth(1.0f);
        glPointSize(1.0f);
        glEnable(GL_LIGHTING);
    }

    ~this()
    {
        Delete(particles);
    }
    
    void free()
    {
        Delete(this);
    }
}
