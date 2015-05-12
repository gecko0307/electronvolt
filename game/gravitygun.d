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
import dmech.constraint;

import game.weapon;
import game.tesla;
import game.fpcamera;

class DragConstraint: Constraint
{
    Vector3f targetPosition;
    bool active = false;
    Vector3f posChange;
    Vector3f posChangeVel;

    this(RigidBody body1)
    {
        this.body1 = body1;
    }

    override void prepare(double dt)
    {
        if (active)
        {
            posChange = (targetPosition - body1.position);
            //posChangeVel = posChange / dt - body1.linearVelocity;
        }
    }
    
    void setBody(RigidBody b) { body1 = b; }
    void setPosition(Vector3f pos) { targetPosition = pos; }

    override void step()
    {
        if (active)
        {
            float d = distance(targetPosition, body1.position);
            if (d > 0.05)
            {
                //Vector3f velChange = posChange - body1.linearVelocity;
                body1.linearVelocity = posChange * 10.0f;
                //body1.linearVelocity += posChangeVel * 0.01f;
                //body1.linearVelocity += posChange * (1.0f / d);
                //body1.applyForce(posChange.normalized * 10.0f);
            }
            else
            {
                body1.position = targetPosition;
                body1.linearVelocity *= 0.0f;
            }
        }
    }
    
    void free()
    {
        Delete(this);
    }
}

class DragConstraint2: Constraint
{
    Vector3f _targetPosition;
    bool active = false;
    BallConstraint bc;
    RigidBody dummyBody;

    this(RigidBody body1)
    {
        this.body1 = body1;
        _targetPosition = Vector3f(0, 0, 0);
        dummyBody = New!RigidBody();
        dummyBody.position = _targetPosition;
        dummyBody.mass = float.infinity;
        dummyBody.invMass = 0.0f;
        dummyBody.inertiaTensor = matrixf(
            float.infinity, 0, 0,
            0, float.infinity, 0,
            0, 0, float.infinity
        );
        dummyBody.invInertiaTensor = matrixf(
            0, 0, 0,
            0, 0, 0,
            0, 0, 0
        );
        dummyBody.dynamic = false;
        bc = New!BallConstraint(body1, dummyBody, Vector3f(0, 0, 0), Vector3f(0, 0, 0));
        bc.biasFactor = 1.0f;
        //bc.softness = 0.001f;
    }
    
    void setBody(RigidBody b)
    {
        body1 = b;
        bc.body1 = b;
    }
    
    void setPosition(Vector3f pos)
    {
        _targetPosition = pos;
        dummyBody.position = _targetPosition;
    }

    override void prepare(double dt)
    {
        if (active)
        {
            //posChange = targetPosition - body1.position;
            //d = distance(targetPosition, body1.position);
            //posChange /= dt;
            bc.prepare(dt);
        }
    }

    override void step()
    {
        if (active)
        {
            bc.step();
        }
    }
    
    void free()
    {
        bc.free();
        dummyBody.free();
        Delete(this);
    }
}

class GravityGun: Weapon
{
    ResourceManager res;
    EventManager eventManager;
    PhysicsWorld world;
    TeslaEffect tesla;
    //float maxVelocityChange = 10.0f;
    DragConstraint dc;
    
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

        //auto glow = new Texture(loadPNG(res.vfs.openForInput("glow.png")));
        tesla = New!TeslaEffect(this, glowTexture, light);
        tesla.start = Vector3f(0, 0.1f, -0.5f);
        tesla.width = 5.0f;
        tesla.color = teslaColor;
        
        //dc = New!DragConstraint(null);
        //world.addConstraint(dc);
        
        //bc = New!BallConstraint(null);
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
                    //dc.active = false;
                }
            }
        }
        else
        {
            canShoot = true;
        }
            
        /*
        if (res.eventManager.rmb_pressed)
        {
            if (shootedBody !is null)
            {
                shootedBody.useGravity = true;
                shootedBody.linearVelocity = camDir * 30.0f;
                shootedBody = null;
            }
        }
        */
        
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
                b.linearVelocity *= 0.1f;
                //b.position = objPos;
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
                //dc.active = false;
            }
            }
        }
    }

    override void free()
    {
        freeContent();
        tesla.free();
        Delete(this);
    }
}
