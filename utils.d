module utils;

private
{
    import derelict.opengl.gl;
    import dlib.math.matrix4x4;
    import dlib.geometry.aabb;
}

Matrix4x4f getMVPMatrix()
{
    Matrix4x4f mvp;

    Matrix4x4f modelViewMatrix;
    glGetFloatv(GL_MODELVIEW_MATRIX, modelViewMatrix.arrayof.ptr);

    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
        glMultMatrixf(modelViewMatrix.arrayof.ptr);
    glGetFloatv(GL_PROJECTION_MATRIX, mvp.arrayof.ptr);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
 
    return mvp;
}

void drawAABB(ref AABB aabb)
{
    glPushMatrix();
    glDisable(GL_LIGHTING);

    glBegin(GL_LINES);
    glVertex3f(aabb.pmin.x, aabb.pmin.y, aabb.pmin.z);
    glVertex3f(aabb.pmin.x, aabb.pmin.y, aabb.pmax.z);

    glVertex3f(aabb.pmax.x, aabb.pmin.y, aabb.pmin.z);
    glVertex3f(aabb.pmax.x, aabb.pmin.y, aabb.pmax.z);

    glVertex3f(aabb.pmin.x, aabb.pmax.y, aabb.pmin.z);
    glVertex3f(aabb.pmin.x, aabb.pmax.y, aabb.pmax.z);

    glVertex3f(aabb.pmax.x, aabb.pmax.y, aabb.pmin.z);
    glVertex3f(aabb.pmax.x, aabb.pmax.y, aabb.pmax.z);

    glVertex3f(aabb.pmin.x, aabb.pmin.y, aabb.pmin.z);
    glVertex3f(aabb.pmax.x, aabb.pmin.y, aabb.pmin.z);

    glVertex3f(aabb.pmin.x, aabb.pmin.y, aabb.pmin.z);
    glVertex3f(aabb.pmin.x, aabb.pmax.y, aabb.pmin.z);

    glVertex3f(aabb.pmax.x, aabb.pmin.y, aabb.pmin.z);
    glVertex3f(aabb.pmax.x, aabb.pmax.y, aabb.pmin.z);

    glVertex3f(aabb.pmin.x, aabb.pmax.y, aabb.pmin.z);
    glVertex3f(aabb.pmax.x, aabb.pmax.y, aabb.pmin.z);

    glVertex3f(aabb.pmin.x, aabb.pmin.y, aabb.pmax.z);
    glVertex3f(aabb.pmax.x, aabb.pmin.y, aabb.pmax.z);

    glVertex3f(aabb.pmin.x, aabb.pmin.y, aabb.pmax.z);
    glVertex3f(aabb.pmin.x, aabb.pmax.y, aabb.pmax.z);

    glVertex3f(aabb.pmax.x, aabb.pmin.y, aabb.pmax.z);
    glVertex3f(aabb.pmax.x, aabb.pmax.y, aabb.pmax.z);

    glVertex3f(aabb.pmin.x, aabb.pmax.y, aabb.pmax.z);
    glVertex3f(aabb.pmax.x, aabb.pmax.y, aabb.pmax.z);
    glEnd();

    glEnable(GL_LIGHTING);
    glPopMatrix();
}

