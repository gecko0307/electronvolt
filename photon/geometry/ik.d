module photon.geometry.ik;

private
{
    import std.algorithm;
    import std.math;
    import dlib.math.utils;
    import dlib.math.vector;
    import dlib.math.quaternion;
    import derelict.opengl.gl;
}

class IKJoint
{
    IKJoint parent = null;
    IKJoint child = null;

    Vector3f pos;  // position in parent space
    Quaternionf rot;

    this(Vector3f position, IKJoint par = null)
    {
        pos = position;
        parent = par;
        if (parent !is null)
            parent.child = this;
        rot = identityQuaternion!float;
    }

    @property Vector3f worldPos()
    {
        Vector3f wp = pos;
        if (parent !is null)
        {
            parent.rot.rotate(wp);
            wp += parent.worldPos;
        }
        return wp;
    }
}

class IKSolverCCD
{
    IKJoint[] bones;
    Vector3f target = Vector3f(0.0f, 0.0f, 0.0f);
    uint chainLength = 0;

    this()
    {
        bones = new IKJoint[6];
        bones[0] = new IKJoint(Vector3f(0.0f, 0.0f, 0.0f));
        bones[1] = new IKJoint(Vector3f(5.0f, 0.0f, 0.0f), bones[0]);
        bones[2] = new IKJoint(Vector3f(5.0f, 0.0f, 0.0f), bones[1]);
        bones[3] = new IKJoint(Vector3f(5.0f, 0.0f, 0.0f), bones[2]);
        bones[4] = new IKJoint(Vector3f(5.0f, 0.0f, 0.0f), bones[3]);
        bones[5] = new IKJoint(Vector3f(5.0f, 0.0f, 0.0f), bones[4]);

        foreach(b; bones)
            chainLength += b.pos.length;
    }

    void solve()
    {
        if ((target - bones[0].worldPos).length > chainLength + 5.0f)
            return;

        uint ITERATION_THRESHOLD = bones.length * 5;
        uint tries = 0;

        enum float EPSILON = 0.0001f; 

        foreach(b; bones)
            b.rot = identityQuaternion!float();

        IKJoint endBone = bones[$-1];

        IKJoint curBone = bones[$-2];
        do
        {
            if (distance(endBone.worldPos, target) > 0.1f)
            {
                Vector3f currentBoneToEndBone = (endBone.worldPos - curBone.worldPos);
                float curToEndMag = currentBoneToEndBone.length;
                currentBoneToEndBone.normalize();
                Vector3f currentBoneToTarget = (target - curBone.worldPos);
                float curToTargetMag = currentBoneToTarget.length;
                currentBoneToTarget.normalize();

                float cosAngle = currentBoneToEndBone.dot(currentBoneToTarget);
                float rotAng = acos(cosAngle); //acos(max(-1.0f, min(1.0f, cosAngle)));

                Vector3f crossResult = currentBoneToEndBone.cross(currentBoneToTarget);
                crossResult.normalize();

                Quaternionf rot = rotation(crossResult, rotAng);
                curBone.rot *= rot;
                curBone.rot.normalize();

                curBone = curBone.parent;
                if (curBone is null) 
                    curBone = bones[$-2];
            }
            else return;
        } 
        while (distance(endBone.worldPos, target) > 0.1f && 
               tries++ < ITERATION_THRESHOLD);
    }

    void draw()
    {
        glDisable(GL_LIGHTING);
        glColor3f(0.0f, 1.0f, 0.0f);

        glBegin(GL_LINE_STRIP);
        foreach(b; bones)
        {
            glVertex3fv(b.worldPos.arrayof.ptr);
        }
        glEnd();

        glPointSize(5.0f);
        glBegin(GL_POINTS);
        foreach(b; bones)
        {
            glVertex3fv(b.worldPos.arrayof.ptr);
        }
        glEnd();

        glColor3f(0.0f, 0.0f, 1.0f);
        glBegin(GL_POINTS);
        glVertex3fv(target.arrayof.ptr);
        glEnd();
        glPointSize(1.0f);

        glColor3f(1.0f, 1.0f, 1.0f);
        glEnable(GL_LIGHTING);
    }
}



