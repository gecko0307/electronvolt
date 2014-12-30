module atrium.fpcamera;

import derelict.opengl.gl;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.math.utils;

import dgl.core.modifier;

class FirstPersonCamera: Modifier
{
    Matrix4x4f transformation;
    Matrix4x4f gunTransformation;
    Vector3f position;
    Vector3f eyePosition = Vector3f(0, 0, 0);
    Vector3f gunPosition = Vector3f(0, 0, 0);
    float turn = 0.0f;
    float pitch = 0.0f;
    float roll = 0.0f;
    float gunPitch = 0.0f;
    float gunRoll = 0.0f;
    
    this(Vector3f position)
    {
        this.position = position;
    }
    
    Matrix4x4f worldTrans(double dt)
    {
        //roll = -gunSway.x * 5.0f;   
        Matrix4x4f m = translationMatrix(position + eyePosition);
        m *= rotationMatrix(Axis.y, degtorad(turn));
        m *= rotationMatrix(Axis.x, degtorad(pitch));
        m *= rotationMatrix(Axis.z, degtorad(roll));
        return m;
    }
    
    override void bind(double dt)
    {
        transformation = worldTrans(dt);
        
        //gunTransformation = transformation * translationMatrix(gunPosition);
        
        gunTransformation = translationMatrix(position + eyePosition);
        gunTransformation *= rotationMatrix(Axis.y, degtorad(turn));
        gunTransformation *= rotationMatrix(Axis.x, degtorad(gunPitch));
        gunTransformation *= rotationMatrix(Axis.z, degtorad(gunRoll));
        gunTransformation *= translationMatrix(gunPosition);
        
        Matrix4x4f worldTransInv = transformation.inverse;
        glPushMatrix();
        glMultMatrixf(worldTransInv.arrayof.ptr);
    }
    
    override void unbind()
    {
        glPopMatrix();
    }

    override void free() {}
}

import dgl.core.drawable;

class Weapon: Drawable
{
    Drawable model;
    Matrix4x4f transformation;
    Vector3f position;
    Vector3f scale;
    FirstPersonCamera camera;
    
    this(FirstPersonCamera camera, Drawable model)
    {
        this.model = model;
        this.transformation = Matrix4x4f.identity;
        this.camera = camera;
        this.position = Vector3f(0, 0, 0);
        this.scale = Vector3f(1, 1, 1);
    }
    
    override void draw(double dt)
    {
        transformation = camera.gunTransformation;
        glPushMatrix();
        glMultMatrixf(transformation.arrayof.ptr);
        glTranslatef(position.x, position.y, position.z);
        //glScalef(scale.x, scale.y, scale.z);
        model.draw(dt);
        glPopMatrix();
    }
    
    override void free() {}
}
