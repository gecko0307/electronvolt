module game.gravitygun;

import std.math;
import std.algorithm;

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

import game.weapon;
import game.tesla;
import game.fpcamera;

class GravityGun: Weapon
{
    ResourceManager res;
    EventManager eventManager;
    PhysicsWorld world;
    TeslaEffect tesla;
    //float maxVelocityChange = 10.0f;
    
    this(Drawable model, Texture glowTexture, FirstPersonCamera camera, ResourceManager rm, EventManager eventManager, PhysicsWorld world)
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
    }
    
    override void draw(double dt)
    {
        super.draw(dt);
        tesla.draw(dt);
    }
    
    RigidBody shootedBody = null;
    float attractDistance = 4.0f;
    bool canShoot = true;
    
    override void shoot()
    {
        Vector3f camPos = camera.transformation.translation;
        Vector3f camDir = -camera.transformation.forward;

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
                        if (distance(cr.point, camPos) < 15.0f)
                        if (cr.rbody.dynamic)
                        {
                            shootedBody = cr.rbody;
                        }
                    }
                }
                else
                {
                    //shootedBody.useGravity = true;
                    shootedBody = null;
                }
            }
        }
        else
        {
            canShoot = true;
        }
        
        tesla.visible = false;
        
        if (shootedBody)
        {
            CastResult cr;
            Vector3f objPos = camPos + camDir * attractDistance;
            Vector3f objDir = (shootedBody.position - camPos).normalized;
        
            //shootedBody.useGravity = false;
            auto b = shootedBody;
            
            Vector3f posChange = objPos - b.position;
            float d = distance(objPos, b.position);

            if (d > 0.001)
            {
                bool ignore = false;
                shootedBody.raycastable = false;
                bool isec = world.raycast(b.position, posChange.normalized, d, cr, true, true);
                shootedBody.raycastable = true;
                if (isec)
                {
                    float dist = distance(b.position, cr.point);
                    if (dist < d)
                    {
                        ignore = true;
                        if (d - dist > 0.3f)
                            shootedBody = null;                   
                    }
                }

                if (!ignore)
                {
                    b.linearVelocity = posChange * 10.0f;
                    float dt = (1.0f / 60.0f);
                    float maxJump = 0.5f;
                    if (b.linearVelocity.length * dt > maxJump)
                        b.linearVelocity = b.linearVelocity.normalized * (maxJump / dt);
                  
                }
            }
            else
            {
                //b.linearVelocity *= 0.1f;
            }

            float d1 = distance(tesla.transformation.translation, b.position);
            tesla.length = d1;
            tesla.visible = true;
            tesla.target = b.position;

            bool isec = world.raycast(camPos, objDir, 100.0f, cr, true, true);
            if (isec)
            {
                //assert(cr.rbody !is null);
                if (cr.rbody !is shootedBody)
                {
                    //if (shootedBody)
                    //    shootedBody.useGravity = true;
                    shootedBody = null;
                }
            }
        }
    }
    
    ~this()
    {
        Delete(tesla);
    }

    override void free()
    {
        Delete(this);
    }
}
