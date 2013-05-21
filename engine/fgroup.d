module engine.fgroup;

import derelict.opengl.gl;
import derelict.opengl.glext;
import dlib.geometry.triangle;
import engine.graphics.material;
import engine.dat;

class FaceGroup
{
    Triangle[] tris;
    uint displayList;
    int materialIndex;
}

FaceGroup[int] createFGroups(DatObject datobj)
{
    FaceGroup[int] fgroups;
    
    foreach(tri; datobj.tris)
    {
        int m = tri.materialIndex;
          
        if (!(m in fgroups))
        {
            fgroups[m] = new FaceGroup();
            fgroups[m].materialIndex = m;
        }
                
        fgroups[m].tris ~= tri;
    }
        
    foreach(fgroup; fgroups)
    {
        fgroup.displayList = glGenLists(1);
        glNewList(fgroup.displayList, GL_COMPILE);
            
        Material* mat = fgroup.materialIndex in datobj.materialByIndex;
           
        if (mat !is null)
            mat.bind(0.0);
         
        foreach(tri; fgroup.tris)
        {               
            glBegin(GL_TRIANGLES);
            glNormal3fv(tri.normal.arrayof.ptr);
            //glNormal3fv(tri.n[0].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[0].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[0].arrayof.ptr);
            glVertex3fv(tri.v[0].arrayof.ptr);
            
            //glNormal3fv(tri.n[1].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[1].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[1].arrayof.ptr);
            glVertex3fv(tri.v[1].arrayof.ptr);
            
            //glNormal3fv(tri.n[2].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[2].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[2].arrayof.ptr);
            glVertex3fv(tri.v[2].arrayof.ptr);
            glEnd();
        }
            
        if (mat !is null)
            mat.unbind();
            
        glEndList();
    }
    
    return fgroups;
}
