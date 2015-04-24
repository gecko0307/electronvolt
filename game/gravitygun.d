module game.gravitygun;

import derelict.sdl.sdl;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.affine;
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
        tesla.width = 3.0f;
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
                    if (cr.rbody.dynamic)
                    {
                        shootedBody = cr.rbody;
                    }
                    }
                }
                else
                {
                    shootedBody.useGravity = true;
                    shootedBody = null;
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
        
            shootedBody.useGravity = false;
            auto b = shootedBody;
            Vector3f fvec = (objPos - b.position).normalized;
            float d = distance(objPos, b.position);
            
            if (d != 0.0f)
            {
                float mag = d * 5.0f;
                float maxJump = 5.0f;
                float magDt = mag * eventManager.deltaTime;
                if (magDt > maxJump)
                    mag -= (magDt - maxJump) / eventManager.deltaTime;
                b.linearVelocity = fvec * mag;
            }

            float d1 = distance(tesla.transformation.translation, b.position);
            tesla.length = d1;
            tesla.visible = true;
            tesla.target = b.position;

            Vector3f objDir = (shootedBody.position - camPos).normalized;
            if (world.raycast(camPos, objDir, 100.0f, cr, true, true))
            {
                assert(cr.rbody !is null);
            if (cr.rbody !is shootedBody)
            {
                if (shootedBody)
                    shootedBody.useGravity = true;
                shootedBody = null;
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
