module game.weapon;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.geometry.aabb;

import dgl.core.api;
import dgl.core.event;
import dgl.core.interfaces;
import dgl.graphics.entity;

import game.fpcamera;

class Weapon: Entity, Modifier
{
    FirstPersonCamera camera;
    
    this(FirstPersonCamera camera, Drawable model)
    {
        super(model);
        this.camera = camera;
    }
    
    override Vector3f getPosition()
    {
        return transformation.translation;
    }
    
    override void update(double dt)
    {
        transformation = camera.gunTransformation;
        transformation *= translationMatrix(position);
        //transformation *= rotation.toMatrix4x4;
    }
    
    Matrix4x4f getTransformation()
    {
        return camera.gunTransformation;
    }
    
    void bind(double dt)
    {
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

    void shoot() {}
}

