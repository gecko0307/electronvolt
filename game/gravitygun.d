module game.gravitygun;

import std.math;
import std.algorithm;
import std.random;

import derelict.opengl.gl;
import derelict.sdl.sdl;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.math.utils;
import dlib.image.color;
import dlib.image.io.png;

import dgl.core.interfaces;
import dgl.core.event;
import dgl.graphics.light;
import dgl.graphics.texture;
import dgl.asset.resman;

import dmech.world;
import dmech.rigidbody;
import dmech.raycast;
import dmech.contact;

import game.weapon;
import game.tesla;
import game.particles;
import game.fpcamera;

class GravityGun: Weapon, CollisionDispatcher
{
    ResourceManager res;
    EventManager eventManager;
    PhysicsWorld world;
    TeslaEffect tesla;
    ParticleSystem sparks;
    
    // TODO: load model and texture here
    this(Drawable model, 
         Texture glowTexture,
         FirstPersonCamera camera,
         ResourceManager rm,
         EventManager eventManager,
         PhysicsWorld world)
    {
        super(camera, model);
        this.res = res;
        this.eventManager = eventManager;
        this.world = world;
        Color4f teslaColor = Color4f(1.0f, 0.5f, 0.0f, 1.0f);
        auto light = pointLight(
            Vector3f(0,0,0), 
            teslaColor,
            Color4f(0,0,0,1),
            0.0f, 0.5f, 0.0f);
        light.enabled = false;
        light.forceOn = true;
        rm.lm.addLight(light);

        tesla = New!TeslaEffect(this, glowTexture, light);
        tesla.start = Vector3f(0, 0.1f, -0.5f);
        tesla.width = 5.0f;
        tesla.color = teslaColor;
        
        sparks = New!ParticleSystem(world, Vector3f(0, 0, 0));
        sparks.collisions = true;
        sparks.primaryColor = Color4f(1.0f, 0.5f, 0.0f, 1.0f);
        sparks.secondaryColor = Color4f(1.0f, 0.0f, 0.0f, 0.0f);
    }
    
    override void draw(double dt)
    {
        sparks.draw(dt);
        super.draw(dt);
        tesla.draw(dt);
    }
    
    RigidBody shootedBody = null;
    float attractDistance = 4.0f;
    bool canShoot = true;

    void onNewContact(RigidBody b, Contact c)
    {
        if (shootedBody)
        {
            shootedBody.position += c.normal * c.penetration;
        }
    }

    void setShootedBody(RigidBody sb)
    {
        shootedBody = sb;       
    }
    
    void unsetShootedBody()
    {
        if (shootedBody)
        {
            //...
        }
        shootedBody = null;
    }

    bool forceTesla = false;
    float forceTeslaTimer = 0.0f;
    
    override void shoot()
    {
        Vector3f camPos = camera.transformation.translation;
        Vector3f camDir = -camera.transformation.forward;
        
        Vector3f objPos = camPos + camDir * attractDistance;

        if (eventManager.mouseButtonPressed[SDL_BUTTON_LEFT])
        {
            if (canShoot)
            {
                canShoot = false;
                if (shootedBody is null)
                {
                    CastResult cr;
                    if (world.raycast(camPos, camDir, 100.0f, cr, true, true))
                    {
                        assert(cr.rbody !is null);
                        if (distance(cr.point, camPos) < 15.0f && cr.rbody.dynamic)
                        {
                            setShootedBody(cr.rbody);
                            sparks.reset(objPos, cr.normal);
                        }
                        else
                        {
                            tesla.length = distance(camPos, cr.point);
                            tesla.visible = true;
                            tesla.target = cr.point;
                            forceTesla = true;
                            forceTeslaTimer = 0.1f;
                            sparks.reset(cr.point, cr.normal);
                        }
                    }
                }
                else
                {
                    unsetShootedBody();
                }
            }
        }
        else if (eventManager.mouseButtonPressed[SDL_BUTTON_RIGHT])
        {
            if (canShoot)
            {
                canShoot = false;
                if (shootedBody is null)
                {
                    CastResult cr;
                    if (world.raycast(camPos, camDir, 100.0f, cr, true, true))
                    {
                        tesla.length = distance(camPos, cr.point);
                        tesla.visible = true;
                        tesla.target = cr.point;
                        forceTesla = true;
                        forceTeslaTimer = 0.1f;
                        sparks.reset(cr.point, cr.normal);
                        
                        if (cr.rbody.dynamic)
                        {
                            float d = distance(objPos, cr.rbody.position);
                            float impulseMag = 200.0f;
                            if (d > 1.0f)
                                impulseMag *= 1.0f / d;
                            cr.rbody.applyImpulse(camDir * impulseMag, cr.rbody.position);
                        }
                    }
                }
            }
        }
        else
        {
            canShoot = true;
        }
        
        if (!forceTesla)
            tesla.visible = false;
        else
        {
            forceTeslaTimer -= eventManager.deltaTime;
            if (forceTeslaTimer <= 0.0f)
                forceTesla = false;
        }
        
        if (shootedBody)
        {
            Vector3f objDir = (shootedBody.position - camPos).normalized;
            CastResult cr;

            auto b = shootedBody;

            Vector3f posChange = objPos - b.position;
            float d = distance(objPos, b.position);
            
            float d2 = distance(camPos, objPos);

            if (d > 0.001)
            {
                bool ignore = false;
                shootedBody.raycastable = false;
                bool isec = world.raycast(b.position, posChange.normalized, d, cr, true, true);
                shootedBody.raycastable = true;
                if (isec)
                {
                    float dist = distance(camPos, cr.point);
                    if (dist < 2.0f || dist < d2 + 1.5f)
                    {
                        ignore = true;
                        if (d - dist > 0.3f)
                            unsetShootedBody();       
                    }
                }

                if (!ignore)
                {
                    if (posChange.lengthsqr < 1.0f)
                        b.linearVelocity = posChange * 10.0f;
                    else
                    {
                        b.linearVelocity = posChange * 10.0f;
                        if (d > 4.0f)
                            b.linearVelocity *= 1.0f / d;
                    }
                    float dt = (1.0f / 60.0f);
                    float maxJump = 0.5f;
                    if (b.linearVelocity.length * dt > maxJump)
                        b.linearVelocity = b.linearVelocity.normalized * (maxJump / dt);
                }
            }

            float d1 = distance(tesla.transformation.translation, b.position);
            tesla.length = d1;
            tesla.visible = true;
            tesla.target = b.position;

            bool isec = world.raycast(camPos, objDir, 100.0f, cr, true, true);
            if (isec)
            {
                if (cr.rbody !is shootedBody)
                {
                    unsetShootedBody();
                }
            }
            
            if (eventManager.mouseButtonPressed[SDL_BUTTON_RIGHT])
            {
                if (shootedBody)
                {
                    shootedBody.applyImpulse(camDir * 200.0f, shootedBody.position);
                    unsetShootedBody();
                }
            }
        }
        
        sparks.update(1.0 / 60.0);
    }
    
    ~this()
    {
        Delete(tesla);
        Delete(sparks);
    }

    override void free()
    {
        Delete(this);
    }
}
