module photon.scene.billboard;

private
{
    import derelict.opengl.gl;

    import dlib.math.vector;
    import dlib.math.matrix4x4;
    
    import photon.scene.scenenode;
}

class Billboard: SceneNode
{
    float width = 1.0f;
    float height = 1.0f;

    private Matrix4x4f modelViewMatrix;

    this(float w, float h, SceneNode par = null)
    {
        super(par);
        width = w;
        height = h;
        //position = Vector3f(0.0f, 0.0f, 0.0f);
    }

    override void render(double delta)
    {
        glPushMatrix();

        glGetFloatv(GL_MODELVIEW_MATRIX, modelViewMatrix.arrayof.ptr);

        glLoadIdentity();

        Vector3f transformedPos = modelViewMatrix.transform(position);

        //glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glBegin(GL_TRIANGLE_STRIP);
        glTexCoord2f(0.0f, 1.0f); glVertex3f(transformedPos.x - width * 0.5f, transformedPos.y + height * 0.5f, transformedPos.z);
        glTexCoord2f(0.0f, 0.0f); glVertex3f(transformedPos.x - width * 0.5f, transformedPos.y - height * 0.5f, transformedPos.z);
        glTexCoord2f(1.0f, 1.0f); glVertex3f(transformedPos.x + width * 0.5f, transformedPos.y + height * 0.5f, transformedPos.z);
        glTexCoord2f(1.0f, 0.0f); glVertex3f(transformedPos.x + width * 0.5f, transformedPos.y - height * 0.5f, transformedPos.z);
        glEnd();

        glPopMatrix();
    }
}

