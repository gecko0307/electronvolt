module game.tesla;

import std.random;

import derelict.opengl.gl;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.image.color;
import dlib.geometry.aabb;

import dgl.graphics.object3d;
import dgl.graphics.texture;
import dgl.graphics.light;

import game.weapon;

class TeslaEffect: Object3D
{
    Vector3f[20] points;
    float length = 1.0f;
    Vector3f target = Vector3f(0, 0, 0);
    Matrix4x4f transformation;
    Weapon weapon;
    bool visible = false;
    float width = 1.0f;
    Vector3f start;
    Color4f color = Color4f(1, 1, 1, 1);
    Texture glowTex;
    Light light;
    
    this(Weapon weapon, Texture glowTex, Light light)
    {
        this.weapon = weapon;
        this.transformation = Matrix4x4f.identity;
        this.start = Vector3f(0,0,0);
        this.glowTex = glowTex;
        this.light = light;
        
        foreach(i, ref p; points)
            p = Vector3f(0, 0, -(cast(float)i)/(points.length-1));
    }
    
    float wildness = 0.1f;
    float vibrate = 0.0f;
    
    void calcPoints(uint left, uint right, float lh, float rh, uint comp)
    {
        float midh;
        uint mid;
        uint res;
        float fracScale;
        
        float random = uniform(0.0f, 1.0f);
        
        mid = (left + right) / 2;
        res = (left + right) % 2;
        fracScale = cast(float)(right - left) / points.length;
        midh = cast(float)(lh + rh) / 2.0f 
             + (fracScale * wildness * random) -
               (fracScale * wildness) / 2.0f;
               
        points[mid][comp] = midh + (vibrate * random - (vibrate / 2));
        
        if (res == 1)
            points[right - 1][comp] = points[right][comp];
        if ((mid - left) > 1)
            calcPoints(left, mid, lh, midh, comp);
        if ((right - mid) > 1)
            calcPoints(mid, right, midh, rh, comp);
    }
    
    override void draw(double dt)
    {
        light.enabled = visible;
        
        if (!visible)
            return;

        calcPoints(0, points.length-1, 0, 0, 0);
        calcPoints(0, points.length-1, 0, 0, 1);
        
        transformation = 
              weapon.transformation 
            * translationMatrix(weapon.position + start);
            
        Vector3f currentDir = transformation.forward;
        Vector3f targetDir = (target - transformation.translation).normalized;
        auto rot = rotationBetweenVectors(-currentDir, targetDir);
        transformation *= rot;
        transformation *= scaleMatrix(Vector3f(length, length,length));
        
        light.position = transformation.translation;
        
        glDisable(GL_LIGHTING);
        
        glPushMatrix();
        glMultMatrixf(transformation.arrayof.ptr);       
        // Draw lightning
        glLineWidth(width);
        glBegin(GL_LINE_STRIP);
        foreach(i, ref p; points)
        {
            glColor4f(color.r, color.g, color.b, (points.length - cast(float)i)/points.length);
            glVertex3fv(p.arrayof.ptr);
        }
        glEnd();
        glLineWidth(1.0f);
        glPopMatrix();

        // Draw glow
/*
        glPushMatrix();
        glDepthMask(GL_FALSE);
        glowTex.bind(dt);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        float size = uniform(0.18f, 0.2f);
        Vector3f pt = Vector3f(0,0,0) * transformation;
        glColor4f(color.r, color.g, color.b, color.a);
        drawBillboard(pt, size);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glowTex.unbind();
        glDepthMask(GL_TRUE);
        glPopMatrix();
*/
        glEnable(GL_LIGHTING);
    }
    
    override Vector3f getPosition()
    {
        return transformation.translation;
    }
    
    void drawBillboard(Vector3f position, float scale)
    {
        Vector3f up = weapon.camera.transformation.up;
        Vector3f right = weapon.camera.transformation.right;
        Vector3f a = position - ((right + up) * scale);
        Vector3f b = position + ((right - up) * scale);
        Vector3f c = position + ((right + up) * scale);
        Vector3f d = position - ((right - up) * scale);
        
        glBegin(GL_QUADS);
        glTexCoord2i(0, 0); glVertex3fv(a.arrayof.ptr);
        glTexCoord2i(1, 0); glVertex3fv(b.arrayof.ptr);
        glTexCoord2i(1, 1); glVertex3fv(c.arrayof.ptr);
        glTexCoord2i(0, 1); glVertex3fv(d.arrayof.ptr);
        glEnd();
    }

    override AABB getAABB()
    {
        return AABB(transformation.translation, Vector3f(1, 1, 1));
    }
    
    override void free()
    {
        //super.freeContent();
        Delete(this);
    }

    mixin ManualModeImpl;
}
