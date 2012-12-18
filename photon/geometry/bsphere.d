module photon.geometry.bsphere;

private
{
    import std.math;
    import std.algorithm;

    import derelict.opengl.gl;

    import dlib.math.vector;

    import photon.geometry.aabb;
}

struct BSphere
{
    Vector3f position;
    float radius;

    this(Vector3f newPosition, float newRadius)
    {
        position = newPosition;
        radius = newRadius;
    }

    bool contains(Vector3f pt)
    {
        float dist = (pt - position).lengthsqr;
        return dist < (radius * radius) ? true : false;
    }

    bool intersectsAABB(AABB b, out Vector3f contactNormal, out float penetrationDepth)
    {
        return b.intersectsSphere(this, contactNormal, penetrationDepth);
    }

    bool intersectsSphere(BSphere sphere, out Vector3f contactNormal, out float penetrationDepth)
    {
        float d = distance(position, sphere.position);
        float sumradius = radius + sphere.radius;

        if (d < sumradius)
        {
            penetrationDepth = sumradius - d;
            contactNormal = position - sphere.position;
            contactNormal.normalize();
            //contactPoint = this.center + intr.contactNormal * other.radius;
            return true;
        }

        return false;
    }
}

