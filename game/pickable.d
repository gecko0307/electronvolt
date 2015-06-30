module game.pickable;

import std.math;
import dlib;
import dgl;
import game.fpcamera;

int ATR_EVENT_PICK_PENTAGON = 1;

class Pickable: Entity
{
    EventManager eventManager;
    Vector4f lightPosition;
    Color4f lightDiffuseColor;
    Color4f lightAmbientColor;
    Color4f glowColor;
    float rot = 0.0f;
    Texture glowTex;
    FirstPersonCamera camera;
    Light light;
    
    this(EventManager em, FirstPersonCamera camera, Drawable model, Texture glowTex, Vector3f pos)
    {
        super(model, pos);
        lightPosition = Vector4f(0, 0, 0, 1);
        lightDiffuseColor = Color4f(1, 1, 1, 1);
        lightAmbientColor = Color4f(0, 0, 0, 1);
        glowColor = Color4f(1, 0, 1, 0.4); // 0.7
        rotation = rotationQuaternion(0, degtorad(-90.0f));
        setTransformation(position, rotation, scaling);
        this.eventManager = em;
        this.camera = camera;
        this.glowTex = glowTex;
    }
    
    override void draw(double dt)
    {       
        if (!visible)
            return;
            
        if (distance(camera.position, position) < 1.0f)
        {
            eventManager.generateUserEvent(ATR_EVENT_PICK_PENTAGON);
            visible = false;
        }
    
        rotation = rotationQuaternion(1, rot) *
                   rotationQuaternion(0, degtorad(-90.0f));
        setTransformation(position, rotation, scaling);
        lightPosition = position + Vector3f(2, 2, 0);
        glEnable(GL_LIGHTING);
        glEnable(GL_LIGHT0);
        glLightfv(GL_LIGHT0, GL_POSITION, lightPosition.arrayof.ptr);
        glLightfv(GL_LIGHT0, GL_SPECULAR, lightDiffuseColor.arrayof.ptr);
        glLightfv(GL_LIGHT0, GL_DIFFUSE, lightDiffuseColor.arrayof.ptr);
        glLightfv(GL_LIGHT0, GL_AMBIENT, lightAmbientColor.arrayof.ptr);
        super.draw(dt);
        glDisable(GL_LIGHTING);
        
        rot += 10.0f * dt * 0.5f;
        if (rot >= 2 * PI)
            rot = 0.0f;
            
        glDisable(GL_LIGHTING);
            
        // Draw glow
        glPushMatrix();
        glDepthMask(GL_FALSE);
        glowTex.bind(dt);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        Vector3f pt = Vector3f(0, 0, 0) * transformation;
        Vector3f n = (camera.transformation.translation - pt).normalized;
        pt += n * 0.5f;
        glColor4fv(glowColor.arrayof.ptr);
        drawBillboard(camera.transformation, pt, 1.0f);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glowTex.unbind();
        glDepthMask(GL_TRUE);
        glPopMatrix();
        
        glEnable(GL_LIGHTING);
        
        if (light)
        {
            if (!visible)
                light.enabled = false;
            else
            {
                light.enabled = true;
                light.position = getPosition();
            }
        }
    }
    
    override void free()
    {
        Delete(this);
    }
}