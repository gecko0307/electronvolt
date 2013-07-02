module engine.glgeom;

import derelict.opengl.gl;
import derelict.opengl.glu;

import dlib.math.vector;

import engine.core.drawable;
import engine.graphics.material;

import engine.physics2.geometry;

interface MaterialObject: Drawable
{
    void setMaterial(Material m);
    Material getMaterial();
    override void draw(double delta);
    void render(double delta);
    override void free();
}

class GLGeomBox: GeomBox, MaterialObject
{
    Material material;
    uint displayList;

    this(Vector3f hsize, Material m = null)
    {
        super(hsize);
        material = m;

        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);

        Vector3f pmax = +halfSize;
        Vector3f pmin = -halfSize;

        glBegin(GL_QUADS);
    
            glNormal3f(0,0,1); glVertex3f(pmin.x,pmin.y,pmax.z);
            glNormal3f(0,0,1); glVertex3f(pmax.x,pmin.y,pmax.z);
            glNormal3f(0,0,1); glVertex3f(pmax.x,pmax.y,pmax.z);
            glNormal3f(0,0,1); glVertex3f(pmin.x,pmax.y,pmax.z);

            glNormal3f(1,0,0); glVertex3f(pmax.x,pmin.y,pmax.z);
            glNormal3f(1,0,0); glVertex3f(pmax.x,pmin.y,pmin.z);
            glNormal3f(1,0,0); glVertex3f(pmax.x,pmax.y,pmin.z);
            glNormal3f(1,0,0); glVertex3f(pmax.x,pmax.y,pmax.z);

            glNormal3f(0,1,0); glVertex3f(pmin.x,pmax.y,pmax.z);
            glNormal3f(0,1,0); glVertex3f(pmax.x,pmax.y,pmax.z);
            glNormal3f(0,1,0); glVertex3f(pmax.x,pmax.y,pmin.z);
            glNormal3f(0,1,0); glVertex3f(pmin.x,pmax.y,pmin.z);

            glNormal3f(0,0,-1); glVertex3f(pmin.x,pmin.y,pmin.z);
            glNormal3f(0,0,-1); glVertex3f(pmin.x,pmax.y,pmin.z);
            glNormal3f(0,0,-1); glVertex3f(pmax.x,pmax.y,pmin.z);
            glNormal3f(0,0,-1); glVertex3f(pmax.x,pmin.y,pmin.z);

            glNormal3f(0,-1,0); glVertex3f(pmin.x,pmin.y,pmin.z);
            glNormal3f(0,-1,0); glVertex3f(pmax.x,pmin.y,pmin.z);
            glNormal3f(0,-1,0); glVertex3f(pmax.x,pmin.y,pmax.z);
            glNormal3f(0,-1,0); glVertex3f(pmin.x,pmin.y,pmax.z);

            glNormal3f(-1,0,0); glVertex3f(pmin.x,pmin.y,pmin.z);
            glNormal3f(-1,0,0); glVertex3f(pmin.x,pmin.y,pmax.z);
            glNormal3f(-1,0,0); glVertex3f(pmin.x,pmax.y,pmax.z);
            glNormal3f(-1,0,0); glVertex3f(pmin.x,pmax.y,pmin.z);
        
        glEnd();

        glEndList();
    }
    
    void render(double delta)
    {
        glPushMatrix();
        glMultMatrixf(transformation.arrayof.ptr);
    
        glCallList(displayList);

        glPopMatrix();
    }
    
    override void draw(double delta)
    {
        if (material)
            material.bind(delta);

        render(delta);

        if (material)
            material.unbind();
    }
    
    override void free()
    {
        glDeleteLists(displayList, 1);
    }
    
    override void setMaterial(Material m)
    {
        material = m;
    }
    
    override Material getMaterial()
    {
        return material;
    }
}

class GLGeomSphere: GeomSphere, MaterialObject
{
    GLUquadricObj* quadric;
    // TODO: slices, stacks
    uint displayList;

    Material material;
    
    this(float r, Material m = null)
    {
        super(r);

        material = m;
        
        quadric = gluNewQuadric();
        gluQuadricNormals(quadric, GLU_SMOOTH);
        gluQuadricTexture(quadric, GL_TRUE);

        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);
        gluSphere(quadric, radius, 24, 16);
        glEndList();
    }
    
    void render(double delta)
    {
        glPushMatrix();
        glMultMatrixf(transformation.arrayof.ptr);
        glCallList(displayList);
        glPopMatrix();
    }
    
    override void draw(double delta)
    {
        if (material)
            material.bind(delta);

        render(delta);

        if (material)
            material.unbind();
    }
    
    override void free()
    {
        gluDeleteQuadric(quadric);
        glDeleteLists(displayList, 1);
    }
    
    override void setMaterial(Material m)
    {
        material = m;
    }
    
    override Material getMaterial()
    {
        return material;
    }
}

class GLGeomCylinder: GeomCylinder, MaterialObject
{
    GLUquadricObj* quadric;
    // TODO: slices, stacks
    uint displayList;

    Material material;
    
    this(float h, float r, Material m = null)
    {
        super(h, r);

        material = m;
        
        quadric = gluNewQuadric();
        gluQuadricNormals(quadric, GLU_SMOOTH);
        gluQuadricTexture(quadric, GL_TRUE);

        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);
        glTranslatef(0.0f, height * 0.5f, 0.0f);
        glRotatef(90.0f, 1.0f, 0.0f, 0.0f);
        gluCylinder(quadric, radius, radius, height, 16, 2);
        gluQuadricOrientation(quadric, GLU_INSIDE);
        gluDisk(quadric, 0, radius, 16, 1);  
        gluQuadricOrientation(quadric, GLU_OUTSIDE);
        glTranslatef(0.0f, 0.0f, height);
        gluDisk(quadric, 0, radius, 16, 1); 
        glEndList();
    }
    
    void render(double delta)
    {
        glPushMatrix();
        glMultMatrixf(transformation.arrayof.ptr);
        glCallList(displayList);
        glPopMatrix();
    }
    
    override void draw(double delta)
    {
        if (material)
            material.bind(delta);

        render(delta);

        if (material)
            material.unbind();
    }
    
    override void free()
    {
        gluDeleteQuadric(quadric);
        glDeleteLists(displayList, 1);
    }
    
    override void setMaterial(Material m)
    {
        material = m;
    }
    
    override Material getMaterial()
    {
        return material;
    }
}

class GLGeomTriangle: GeomTriangle, MaterialObject
{
    uint displayList;
    Material material;
    
    this(Vector3f a, Vector3f b, Vector3f c, Material m = null)
    {
        super(a, b, c);

        material = m;
        
        auto n = normal(a, b, c);

        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);
        glDisable(GL_CULL_FACE);
        //glDisable(GL_LIGHTING);
        glBegin(GL_TRIANGLES);
            glNormal3f(n.x, n.y, n.z);
            glVertex3fv(v[0].arrayof.ptr);
            glVertex3fv(v[1].arrayof.ptr);
            glVertex3fv(v[2].arrayof.ptr);
        glEnd();
        //glEnable(GL_LIGHTING);
        glEnable(GL_CULL_FACE);
        glEndList();
    }
    
    void render(double delta)
    {
        glPushMatrix();
        glMultMatrixf(transformation.arrayof.ptr);
        glCallList(displayList);
        glPopMatrix();
    }
    
    override void draw(double delta)
    {
        if (material)
            material.bind(delta);

        render(delta);

        if (material)
            material.unbind();
    }
    
    override void free()
    {
        glDeleteLists(displayList, 1);
    }
    
    override void setMaterial(Material m)
    {
        material = m;
    }
    
    override Material getMaterial()
    {
        return material;
    }
}

