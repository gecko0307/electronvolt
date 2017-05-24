module game.tesla;

import std.random;
import std.math;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.image.color;
import dlib.geometry.aabb;

import dgl.core.api;
import dgl.graphics.entity;
import dgl.graphics.texture;
import dgl.graphics.light;
//import dgl.graphics.billboard;

import game.weapon;

class TeslaEffect
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
    Light light;
    
    this(Weapon weapon, Light light)
    {
        this.weapon = weapon;
        this.transformation = Matrix4x4f.identity;
        this.start = Vector3f(0,0,0);
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
    
    void draw(double dt)
    {
        light.enabled = visible;
        
        if (!visible)
            return;

        calcPoints(0, points.length-1, 0, 0, 0);
        calcPoints(0, points.length-1, 0, 0, 1);
        
        
        auto wTrans = weapon.getTransformation() * translationMatrix(start);
        Vector3f targetDir = -(target - wTrans.translation).normalized;
        Vector3f up = cross(targetDir, wTrans.up);
        Vector3f right = cross(targetDir, up);

        Vector3f startPoint = wTrans.translation;
        
        float d = distance(startPoint, target);
        
        auto lightTrans = weapon.getTransformation() * translationMatrix(start + Vector3f(0, 1, 0));
        light.position = lightTrans.translation;
        
        glDisable(GL_LIGHTING);
        //glDisable(GL_DEPTH_TEST);
        
        glPushMatrix();
        //glTranslatef(startPoint.x, startPoint.y, startPoint.z);
        // Draw lightning        
        glLineWidth(width);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        float coef = (1.0f / cast(float)(points.length - 1)) * PI;
        glBegin(GL_LINE_STRIP);
        foreach(i, ref p; points)
        {
		    float a = 1.0f;
			if (i > 15)
			    a = (points.length - cast(float)i)/points.length;
            glColor4f(color.r, color.g, color.b, a);
            Vector3f v = startPoint + up * 0.12f;
            v += (targetDir * p.z * d + right * p.x * d + up * p.y * d);
            v += (up) * 0.5f * sin(cast(float)i * coef) * 0.5f;
            glVertex3fv(v.arrayof.ptr);
        }
        glEnd();
        glBegin(GL_LINE_STRIP);
        foreach(i, ref p; points)
        {
		    float a = 1.0f;
			if (i > 15)
			    a = (points.length - cast(float)i)/points.length;
            glColor4f(color.r, color.g, color.b, a);
            Vector3f v = startPoint - up * 0.12f;
            v += (targetDir * p.z * d + right * p.x * d + up * p.y * d);
            v += (-up) * 0.5f * sin(cast(float)i * coef) * 0.5f;
            glVertex3fv(v.arrayof.ptr);
        }
        glEnd();
	    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glLineWidth(1.0f);
        glPopMatrix();
        
        //glEnable(GL_DEPTH_TEST);

        // Draw glow
        /*
        glPushMatrix();
        glDepthMask(GL_FALSE);
        glowTex.bind(dt);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        float size = uniform(0.18f, 0.2f);
        Vector3f pt = Vector3f(0,0,0) * transformation;
        glColor4f(color.r, color.g, color.b, color.a);
        drawBillboard(weapon.camera.transformation, pt, size);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glowTex.unbind();
        glDepthMask(GL_TRUE);
        glPopMatrix();
		*/
        
        glEnable(GL_LIGHTING);
    }
    
    Vector3f getPosition()
    {
        return transformation.translation;
    }

    AABB getAABB()
    {
        return AABB(transformation.translation, Vector3f(1, 1, 1));
    }
}
