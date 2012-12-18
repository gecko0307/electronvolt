module photon.geometry.frustum;

private
{
    import std.math;

    import dlib.math.vector;
    import dlib.math.matrix4x4;
    import dlib.geometry.plane;

    import photon.geometry.aabb;
    import photon.geometry.bsphere;
}

struct Frustum
{
    union
    {
        Plane[6] planes;
        struct
        {
            Plane leftPlane;
            Plane rightPlane;
            Plane bottomPlane;
            Plane topPlane;
            Plane farPlane;
            Plane nearPlane;
        }
    }

    void setFromMVP(Matrix4x4f mvp)
    {
        leftPlane.a = mvp[3]  + mvp[0];
        leftPlane.b = mvp[7]  + mvp[4];
        leftPlane.c = mvp[11] + mvp[8];
        leftPlane.d = mvp[15] + mvp[12];
        leftPlane.normalize();

        rightPlane.a = mvp[3]  - mvp[0];
        rightPlane.b = mvp[7]  - mvp[4];
        rightPlane.c = mvp[11] - mvp[8];
        rightPlane.d = mvp[15] - mvp[12];
        rightPlane.normalize();

        bottomPlane.a = mvp[3]  + mvp[1];
        bottomPlane.b = mvp[7]  + mvp[5];
        bottomPlane.c = mvp[11] + mvp[9];
        bottomPlane.d = mvp[15] + mvp[13];
        bottomPlane.normalize();

        topPlane.a = mvp[3]  - mvp[1];
        topPlane.b = mvp[7]  - mvp[5];
        topPlane.c = mvp[11] - mvp[9];
        topPlane.d = mvp[15] - mvp[13];
        topPlane.normalize();

        farPlane.a = mvp[3]  - mvp[2];
        farPlane.b = mvp[7]  - mvp[6];
        farPlane.c = mvp[11] - mvp[10];
        farPlane.d = mvp[15] - mvp[14];
        farPlane.normalize();

        nearPlane.a = mvp[3]  + mvp[2];
        nearPlane.b = mvp[7]  + mvp[6];
        nearPlane.c = mvp[11] + mvp[10];
        nearPlane.d = mvp[15] + mvp[14];
        nearPlane.normalize();
    }

    bool containsPoint(Vector3f point, bool checkNearPlane = false)
    {
        int res = 0;

        foreach(i, ref p; planes)
        {
            if (i == 5 && !checkNearPlane)
                break;

            if (p.distance(point) >= 0.0f)
                res++;
        }

        return (res == (checkNearPlane? 6 : 5));
    }

    bool containsBsphere(BSphere bsphere, bool checkNearPlane = false)
    {
	    float distance;

        distance = leftPlane.distance(bsphere.position);
        if (distance <= -bsphere.radius)
            return false;

        distance = rightPlane.distance(bsphere.position);
        if (distance <= -bsphere.radius)
            return false;

        distance = bottomPlane.distance(bsphere.position);
        if (distance <= -bsphere.radius)
            return false;

        distance = topPlane.distance(bsphere.position);
        if (distance <= -bsphere.radius)
            return false;

        distance = farPlane.distance(bsphere.position);
        if (distance <= -bsphere.radius)
            return false;

        if (!checkNearPlane)
            return true;

        distance = nearPlane.distance(bsphere.position);
        if (distance <= -bsphere.radius)
            return false;

        return true;
    }

    bool containsAABB(AABB aabb, bool checkNearPlane = false)
    {
        Vector3f topFrontRight = aabb.position + Vector3f(+aabb.size.x, +aabb.size.y, +aabb.size.z);
        Vector3f topFrontLeft  = aabb.position + Vector3f(-aabb.size.x, +aabb.size.y, +aabb.size.z);
        Vector3f topBackRight  = aabb.position + Vector3f(+aabb.size.x, +aabb.size.y, -aabb.size.z);
        Vector3f topBackLeft   = aabb.position + Vector3f(-aabb.size.x, +aabb.size.y, -aabb.size.z);

        Vector3f bottomFrontRight = aabb.position + Vector3f(+aabb.size.x, -aabb.size.y, +aabb.size.z);
        Vector3f bottomFrontLeft  = aabb.position + Vector3f(-aabb.size.x, -aabb.size.y, +aabb.size.z);
        Vector3f bottomBackRight  = aabb.position + Vector3f(+aabb.size.x, -aabb.size.y, -aabb.size.z);
        Vector3f bottomBackLeft   = aabb.position + Vector3f(-aabb.size.x, -aabb.size.y, -aabb.size.z);

        if (containsPoint(topFrontRight,    checkNearPlane)) return true;
        if (containsPoint(topFrontLeft,     checkNearPlane)) return true;
        if (containsPoint(topBackRight,     checkNearPlane)) return true;
        if (containsPoint(topBackLeft,      checkNearPlane)) return true;

        if (containsPoint(bottomFrontRight, checkNearPlane)) return true;
        if (containsPoint(bottomFrontLeft,  checkNearPlane)) return true;
        if (containsPoint(bottomBackRight,  checkNearPlane)) return true;
        if (containsPoint(bottomBackLeft,   checkNearPlane)) return true;

        return false;
    }

    bool intersectsAABB(AABB aabb)
    {
        bool result;

        foreach (ref plane; planes)
        {
            float d = aabb.position.x * plane.normal.x + 
                      aabb.position.y * plane.normal.y + 
                      aabb.position.z * plane.normal.z;

            float r = aabb.size.x * abs(plane.normal.x) + 
                      aabb.size.y * abs(plane.normal.y) + 
                      aabb.size.z * abs(plane.normal.z);
 
            float d_p_r = d + r;
            float d_m_r = d - r;
 
            if (d_p_r < -plane.d)
            {
                result = false; // Outside
                break;
            }
            else if (d_m_r < -plane.d)
                result = true;  // Intersect
        }

        return result;
    }
}

