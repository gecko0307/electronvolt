module photon.scene.primitives;

private
{
    import std.algorithm;
    import derelict.opengl.gl;
    import derelict.opengl.glu;
    import dlib.math.vector;
    import dlib.math.utils;
    import photon.scene.scenenode;
    import photon.geometry.aabb;
    import photon.geometry.bsphere;
}

final class Sphere: SceneNode
{
    GLUquadricObj *quadratic;
    float radius;
    int slices;
    int stacks;

    this(float radius, int slices, int stacks, SceneNode par = null)
    {
        super(par);

        this.radius = radius;
        this.slices = slices;
        this.stacks = stacks;

        quadratic = gluNewQuadric();
        gluQuadricNormals(quadratic, GLU_SMOOTH);
        gluQuadricTexture(quadratic, GL_TRUE);
    }

    override void render(double delta)
    {
        gluSphere(quadratic, radius, slices, stacks);
    }

    override void clean()
    {
        gluDeleteQuadric(quadratic);
    }

    override @property BSphere boundingSphere()
    {
        return BSphere(absolutePosition, radius);
    }
}

final class Box: SceneNode
{
    Vector3f size;

    this(Vector3f size, SceneNode par = null)
    {
        super(par);
        this.size = size;
    }

    override void render(double delta)
    {
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glBegin(GL_QUADS);
            glNormal3f(0.0f, 1.0f, 0.0f);
            glVertex3f( size.x,  size.y, -size.z); // Top Right Of The Quad (Top)
            glVertex3f(-size.x,  size.y, -size.z); // Top Left Of The Quad (Top)
            glVertex3f(-size.x,  size.y,  size.z); // Bottom Left Of The Quad (Top)
            glVertex3f( size.x,  size.y,  size.z); // Bottom Right Of The Quad (Top)

            glNormal3f(0.0f, -1.0f, 0.0f);
            glVertex3f( size.x, -size.y,  size.z); // Top Right Of The Quad (Bottom)
            glVertex3f(-size.x, -size.y,  size.z); // Top Left Of The Quad (Bottom)
            glVertex3f(-size.x, -size.y, -size.z); // Bottom Left Of The Quad (Bottom)
            glVertex3f( size.x, -size.y, -size.z); // Bottom Right Of The Quad (Bottom)

            glNormal3f(0.0f, 0.0f, 1.0f);
            glVertex3f( size.x,  size.y,  size.z); // Top Right Of The Quad (Front)
            glVertex3f(-size.x,  size.y,  size.z); // Top Left Of The Quad (Front)
            glVertex3f(-size.x, -size.y,  size.z); // Bottom Left Of The Quad (Front)
            glVertex3f( size.x, -size.y,  size.z); // Bottom Right Of The Quad (Front)

            glNormal3f(0.0f, 0.0f, -1.0f);
            glVertex3f( size.x, -size.y, -size.z); // Bottom Left Of The Quad (Back)
            glVertex3f(-size.x, -size.y, -size.z); // Bottom Right Of The Quad (Back)
            glVertex3f(-size.x,  size.y, -size.z); // Top Right Of The Quad (Back)
            glVertex3f( size.x,  size.y, -size.z); // Top Left Of The Quad (Back)

            glNormal3f(-1.0f, 0.0f, 0.0f);
            glVertex3f(-size.x,  size.y,  size.z); // Top Right Of The Quad (Left)
            glVertex3f(-size.x,  size.y, -size.z); // Top Left Of The Quad (Left)
            glVertex3f(-size.x, -size.y, -size.z); // Bottom Left Of The Quad (Left)
            glVertex3f(-size.x, -size.y,  size.z); // Bottom Right Of The Quad (Left)

            glNormal3f(1.0f, 0.0f, 0.0f);
            glVertex3f( size.x,  size.y, -size.z); // Top Right Of The Quad (Right)
            glVertex3f( size.x,  size.y,  size.z); // Top Left Of The Quad (Right)
            glVertex3f( size.x, -size.y,  size.z); // Bottom Left Of The Quad (Right)
            glVertex3f( size.x, -size.y, -size.z); // Bottom Right Of The Quad (Right)
        glEnd();
    }

    override @property AABB boundingBox()
    {
        return AABB(absolutePosition, size);
    }

    override @property BSphere boundingSphere()
    {
        return BSphere(absolutePosition, max(size.x, size.y, size.z));
    }
}

