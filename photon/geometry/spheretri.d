module photon.collision.spheretri;

private
{
    import std.math;
    import dlib.math.utils;
    import dlib.math.vector;
    import photon.geometry.triangle;
}

struct IntersectionTestResult
{
    Vector3f contactA;
    Vector3f contactB;
    Vector3f contactNormal;
    float penetrationDepth;
    bool valid;
}

void measureSphereAndTriVert(
        Vector3f center, 
        float radius, 
        ref IntersectionTestResult result, 
        Triangle tri, 
        int whichVert)
{
    Vector3f diff = center - tri.v[whichVert];    
    float len = diff.length;
    float penetrate = radius - len;
    if (penetrate > 0.0f)
    {
        result.valid = true;
        result.penetrationDepth = penetrate;
        result.contactNormal = diff * (1.0f / len);
        result.contactA = center - result.contactNormal * radius;
        result.contactB = tri.v[whichVert];
    }
}

void measureSphereAndTriEdge(
        Vector3f center, 
        float radius, 
        ref IntersectionTestResult result, 
        Triangle tri, 
        int whichEdge)
{
    static int[] nextDim1 = [1, 2, 0];
    static int[] nextDim2 = [2, 0, 1];

    int whichVert0, whichVert1;
    whichVert0 = whichEdge;
    whichVert1 = nextDim1[whichEdge];
    float penetrate;
    Vector3f dir = tri.edges[whichEdge];
    float edgeLen = dir.length;
    if (isConsiderZero(edgeLen))
        dir = Vector3f(0.0f, 0.0f, 0.0f);
    else
        dir *= (1.0f / edgeLen);
    Vector3f vert2Point = center - tri.v[whichVert0];
    float dot = dir.dot(vert2Point);
    Vector3f project = tri.v[whichVert0] + dot * dir;
    if (dot > 0.0f && dot < edgeLen)
    {
        Vector3f diff = center - project;
        float len = diff.length;
        penetrate = radius - len;
        if (penetrate > 0.0f && penetrate < result.penetrationDepth && penetrate < radius)
        {
            result.valid = true;
            result.penetrationDepth = penetrate;
            result.contactNormal = diff * (1.0f / len);
            result.contactA = center - result.contactNormal * radius;
            result.contactB = project;
        }
    }
}

bool testSphereVsTriangle(
    Vector3f center, 
    float radius, 
    ref IntersectionTestResult result, 
    Triangle tri)
{
    //check sphere and triangle plane
    result.penetrationDepth = 1.0e5f;
    result.valid = false;

    //Plane triPlane = Plane(tri);
    float distFromPlane = tri.normal.dot(center) - tri.d;

    float factor = 1.0f;

    if (distFromPlane < 0.0f)
        factor = -1.0f;

    float penetrated = radius - distFromPlane * factor;

    if (penetrated <= 0.0f)
        return false;

    Vector3f contactB = center - tri.normal * distFromPlane;

    int pointInside = tri.isPointInside(contactB);

    if (pointInside == -1) // inside the triangle
    {
        result.penetrationDepth = penetrated;
        result.contactA = center - tri.normal * factor * radius; //on the sphere
        result.contactB = contactB;
        result.valid = true;
        result.contactNormal = tri.normal * factor;
        return true;
    }

    switch (pointInside)
    {
    case 0:
        measureSphereAndTriVert(center, radius, result, tri, 0);
        break;

    case 1:
        measureSphereAndTriEdge(center, radius, result, tri, 0);
        break;

    case 2:
        measureSphereAndTriVert(center, radius, result, tri, 1);
        break;

    case 3:
        measureSphereAndTriEdge(center, radius, result, tri, 1);
        break;

    case 4:
        measureSphereAndTriVert(center, radius, result, tri, 2);
        break;

    case 5:
        measureSphereAndTriEdge(center, radius, result, tri, 2);
        break;
        
    default:
        break;
    }
    
    return result.valid;
}
