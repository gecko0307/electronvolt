module game.gravitygun;

import std.math;
import std.algorithm;
import std.random;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.math.utils;
import dlib.image.color;
import dlib.image.io.png;

import dgl.core.api;
import dgl.core.interfaces;
import dgl.core.event;
import dgl.graphics.light;
import dgl.graphics.texture;
import dgl.graphics.entity;

import dmech.world;
import dmech.rigidbody;
import dmech.raycast;
import dmech.contact;

import game.weapon;
import game.tesla;
import game.particles;
import game.fpcamera;

class GravityGun: Weapon
{
    EventManager eventManager;
    PhysicsWorld world;
    TeslaEffect tesla;
    ParticleSystem sparks;
    Entity shootFX;

    this(Drawable model, 
         Entity shootFX,
         FirstPersonCamera camera,
         EventManager eventManager,
         LightManager lightManager,
         PhysicsWorld world, 
         Vector3f bulletStartPos)
    {
        super(camera, model);
        this.eventManager = eventManager;
        this.world = world;
        Color4f teslaColor = Color4f(1.0f, 0.5f, 0.0f, 1.0f);
        auto light = pointLight(
            Vector3f(0,0,0), 
            teslaColor,
            Color4f(0,0,0,1),
            0.0f, 0.5f, 0.0f);
        light.enabled = false;
        light.highPriority = true;
        lightManager.addLight(light);

        tesla = New!TeslaEffect(this, light);
        tesla.start = bulletStartPos;
        tesla.width = 5.0f;
        tesla.color = teslaColor;
        
        sparks = New!ParticleSystem(world, Vector3f(0, 0, 0));
        sparks.collisions = true;
        sparks.primaryColor = Color4f(1.0f, 0.5f, 0.0f, 1.0f);
        sparks.secondaryColor = Color4f(1.0f, 0.0f, 0.0f, 0.0f);
        
        if (shootFX)
            this.shootFX = shootFX;
        else
            this.shootFX = null;
    }
    /*
    void enableGravity(bool mode)
    {
        if (mode)
            sparks.gravityVector = Vector3f(0, -1, 0);
        else
            sparks.gravityVector = Vector3f(0, 0, 0);
    }
    */
    override void draw(double dt)
    {
        sparks.draw(dt);
        tesla.draw(dt);
        bind(dt);
        drawModel(dt);
        if (shootFX)
        {
            float size = uniform(0.8f, 1.0f);
            shootFX.scaling = Vector3f(size, size, size);
            shootFX.update(dt);
            shootFX.draw(dt);
        }
        unbind();
    }
    
    RigidBody shootedBody = null;
    RigidBody facingBody = null;
    float attractDistance = 3.0f;
    bool canShoot = true;

/*
    void onNewContact(RigidBody b, Contact c)
    {
        if (shootedBody)
        {
            shootedBody.position += c.normal * c.penetration;
        }
    }
*/
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
                            if (shootFX)
                                shootFX.visible = true;
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
                        if (shootFX)
                            shootFX.visible = true;
                        tesla.target = cr.point;
                        forceTesla = true;
                        forceTeslaTimer = 0.1f;
                        sparks.reset(cr.point, cr.normal);
                        
                        if (cr.rbody.dynamic)
                        {
                            float d = distance(objPos, cr.rbody.position);
                            float impulseMag = 1000.0f;
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
            /*
            CastResult cr;
            if (world.raycast(camPos, camDir, 100.0f, cr, true, true))
            {
                if (cr.rbody.dynamic)
                    facingBody = cr.rbody;
                else
                    facingBody = null;
            }
            else
                facingBody = null;
            */
        }
        
        if (!forceTesla)
        {
            tesla.visible = false;
            if (shootFX)
                shootFX.visible = false;
        }
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
            if (shootFX)
                shootFX.visible = true;

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
                    sparks.reset(objPos, -camDir);
                    shootedBody.applyImpulse(camDir * 1000.0f, shootedBody.position);
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
}
