module atrium.entity;

import derelict.opengl.gl;

import dlib.math.vector;
import dlib.math.matrix;

import dgl.core.drawable;
import dgl.graphics.material;

import dmech.shape;

class DynamicEntity: Drawable
{   
    ShapeComponent shape;
    Drawable drawable;
    Material material;
    Matrix4x4f localTransformation;
    Vector3f scale = Vector3f(1, 1, 1);

    this()
    {
        localTransformation = Matrix4x4f.identity;
    }
    
    void draw(double delta)
    {
        if (material !is null)
            material.bind(delta);

        glPushMatrix();
        if (shape !is null)
        {
            glMultMatrixf(shape.transformation.arrayof.ptr);
            glMultMatrixf(localTransformation.arrayof.ptr);
            glScalef(scale.x, scale.y, scale.z);
        }
        if (drawable !is null)
            drawable.draw(delta);
        glPopMatrix();

        if (material !is null)
            material.unbind();
    }
    
    void free() {}
}
