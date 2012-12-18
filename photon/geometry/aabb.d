module photon.geometry.aabb;

private
{
    import std.math;
    import std.algorithm;
    import derelict.opengl.gl;
    import dlib.math.vector;
    import photon.geometry.bsphere;
}

struct AABB
{
    Vector3f position;
    Vector3f size;
    Vector3f pmin, pmax;

    this(Vector3f newPosition, Vector3f newSize)
    {
        position = newPosition;
        size = newSize;
        
        pmin = position - size;
        pmax = position + size;
    }

    float getTopHeight()
    {
        return (position.y + size.y);
    }

    float getBottomHeight()
    {
        return (position.y - size.y);
    }

    Vector3f closestPoint(Vector3f point)
    {
        Vector3f closest;
        closest.x = (point.x < pmin.x)? pmin.x : ((point.x > pmax.x)? pmax.x : point.x);
        closest.y = (point.y < pmin.y)? pmin.y : ((point.y > pmax.y)? pmax.y : point.y);
        closest.z = (point.z < pmin.z)? pmin.z : ((point.z > pmax.z)? pmax.z : point.z);
        return closest;
    }

    bool contains(Vector3f point)
    {
        return !(point.x < pmin.x || point.x > pmax.x || 
                 point.y < pmin.y || point.y > pmax.y || 
                 point.z < pmin.z || point.z > pmax.z);
    }

    bool intersectsAABB(AABB b)
    {
        Vector3f t = b.position - position;
        return fabs(t.x) <= (size.x + b.size.x) &&
               fabs(t.y) <= (size.y + b.size.y) &&
               fabs(t.z) <= (size.z + b.size.z);
    }

    bool intersectsSphere(
        BSphere sphere, 
        out Vector3f collisionNormal, 
        out float penetrationDepth)
    {
        penetrationDepth = 0.0f;
        collisionNormal = Vector3f(0.0f, 0.0f, 0.0f);

        if (contains(sphere.position))
            return true;

        Vector3f xClosest = closestPoint(sphere.position);
        Vector3f xDiff = sphere.position - xClosest;

        float fDistSquared = xDiff.lengthsqr();
        if (fDistSquared > sphere.radius * sphere.radius)
            return false;

        float fDist = sqrt(fDistSquared);
        penetrationDepth = sphere.radius - fDist;
        collisionNormal = xDiff / fDist;
        collisionNormal.normalize();
        return true;    
    }

    private bool intersectsRaySlab(
        float slabmin, 
        float slabmax, 
        float raystart, 
        float rayend, 
        ref float tbenter, 
        ref float tbexit)
    {
        float raydir = rayend - raystart;

        if (fabs(raydir) < 1.0e-9f)
        {
            if (raystart < slabmin || raystart > slabmax)
                return false;
            else
                return true;
        }

        float tsenter = (slabmin - raystart) / raydir;
        float tsexit = (slabmax - raystart) / raydir;

        if (tsenter > tsexit)
        {
            swap(tsenter, tsexit);
        }

        if (tbenter > tsexit || tsenter > tbexit)
        {
            return false;
        }
        else
        {
            tbenter = max(tbenter, tsenter);
            tbexit = min(tbexit, tsexit);
            return true;
        }
    }

    bool intersectsSegment(
        Vector3f segStart, 
        Vector3f segEnd, 
        ref float intersectionTime)
    {
        float tenter = 0.0f, texit = 1.0f; 

        if (!intersectsRaySlab(pmin.x, pmax.x, segStart.x, segEnd.x, tenter, texit)) 
            return false;

        if (!intersectsRaySlab(pmin.y, pmax.y, segStart.y, segEnd.y, tenter, texit)) 
            return false;

        if (!intersectsRaySlab(pmin.z, pmax.z, segStart.z, segEnd.z, tenter, texit)) 
            return false;

        intersectionTime = tenter;

        return true;
    }

    void draw()
    {
        glPushMatrix();
        glDisable(GL_LIGHTING);

        glBegin(GL_LINES);
        glVertex3f(pmin.x, pmin.y, pmin.z);
        glVertex3f(pmin.x, pmin.y, pmax.z);

        glVertex3f(pmax.x, pmin.y, pmin.z);
        glVertex3f(pmax.x, pmin.y, pmax.z);

        glVertex3f(pmin.x, pmax.y, pmin.z);
        glVertex3f(pmin.x, pmax.y, pmax.z);

        glVertex3f(pmax.x, pmax.y, pmin.z);
        glVertex3f(pmax.x, pmax.y, pmax.z);

        glVertex3f(pmin.x, pmin.y, pmin.z);
        glVertex3f(pmax.x, pmin.y, pmin.z);

        glVertex3f(pmin.x, pmin.y, pmin.z);
        glVertex3f(pmin.x, pmax.y, pmin.z);

        glVertex3f(pmax.x, pmin.y, pmin.z);
        glVertex3f(pmax.x, pmax.y, pmin.z);

        glVertex3f(pmin.x, pmax.y, pmin.z);
        glVertex3f(pmax.x, pmax.y, pmin.z);

        glVertex3f(pmin.x, pmin.y, pmax.z);
        glVertex3f(pmax.x, pmin.y, pmax.z);

        glVertex3f(pmin.x, pmin.y, pmax.z);
        glVertex3f(pmin.x, pmax.y, pmax.z);

        glVertex3f(pmax.x, pmin.y, pmax.z);
        glVertex3f(pmax.x, pmax.y, pmax.z);

        glVertex3f(pmin.x, pmax.y, pmax.z);
        glVertex3f(pmax.x, pmax.y, pmax.z);
        glEnd();

        glEnable(GL_LIGHTING);
        glPopMatrix();
    }
}

AABB boxFromMinMaxPoints(Vector3f mi, Vector3f ma)
{
    AABB box;
    box.pmin = mi;
    box.pmax = ma;
    box.position = (box.pmax + box.pmin) * 0.5f;
    box.size = box.pmax - box.position;
    box.size.x = abs(box.size.x);
    box.size.y = abs(box.size.y);
    box.size.z = abs(box.size.z);
    return box;
}


