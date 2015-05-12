module dgl.graphics.billboard;

import derelict.opengl.gl;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;

void drawBillboard(Matrix4x4f cameraTransformation, Vector3f position, float scale)
{
    Vector3f up = cameraTransformation.up;
    Vector3f right = cameraTransformation.right;
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