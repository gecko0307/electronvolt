module game.weapon;

import derelict.opengl.gl;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.geometry.aabb;

import dgl.core.event;
import dgl.core.interfaces;
import dgl.graphics.entity;

import game.fpcamera;

abstract class Weapon: Entity, Modifier
{
    FirstPersonCamera camera;
    
    this(FirstPersonCamera camera, Drawable model)
    {
        super(model, Vector3f(0, 0, 0));
        this.camera = camera;
    }
    
    override Vector3f getPosition()
    {
        return transformation.translation;
    }
    
    void bind(double dt)
    {
        transformation = camera.gunTransformation;
        transformation *= translationMatrix(position);
        glPushMatrix();
        glMultMatrixf(transformation.arrayof.ptr);
    }
    
    void unbind()
    {
        glPopMatrix();
    }
    
    override void draw(double dt)
    {
        bind(dt);
        drawModel(dt);
        unbind();
    }

    override void freeContent()
    {
        super.freeContent();
    }
    
    override void free()
    {
        freeContent();
        Delete(this);
    }

    void shoot() {}
}

