module photon.scene.bvh;

private
{
    import std.math;
    
    import dlib.core.compound;

    import dlib.math.vector;
    import dlib.math.utils;

    import dlib.geometry.ray;

    import photon.geometry.aabb;
    import photon.scene.scenenode;
    import photon.geometry.frustum;
}

// Returns the axis that has the largest length
Axis boxGetMainAxis(AABB box)
{
    float xl = box.size.x;
    float yl = box.size.y;
    float zl = box.size.z;
         
    if (xl < yl)
    {
        if (yl < zl)
           return Axis.z;
        return Axis.y;
    }
    else if (xl < zl)
        return Axis.z;
    return Axis.x;        
}

struct SplitPlane
{
    public:
    float split;
    Axis axis;
    
    this(float s, Axis ax)
    {
        split = s;
        axis = ax;
    }
}

SplitPlane boxGetSplitPlaneForAxis(AABB box, Axis a)
{
    return SplitPlane(box.position[a], a);
}

Compound!(AABB, AABB) boxSplitWithPlane(AABB box, SplitPlane sp)
{
    Vector3f minLP = box.pmin;
    Vector3f maxLP = box.pmax;
    maxLP[sp.axis] = sp.split;
    
    Vector3f minRP = box.pmin;
    Vector3f maxRP = box.pmax;
    minRP[sp.axis] = sp.split;

    AABB leftB = boxFromMinMaxPoints(minLP, maxLP);
    AABB rightB = boxFromMinMaxPoints(minRP, maxRP);

    return compound(leftB, rightB);
}

AABB boxFromObjects(T) (T[] objects)
{
    Vector3f pmin = objects[0].boundingBox.pmin;
    Vector3f pmax = pmin;
    
    void adjustMinPoint(Vector3f p)
    {    
        if (p.x < pmin.x) pmin.x = p.x;
        if (p.y < pmin.y) pmin.y = p.y;
        if (p.z < pmin.z) pmin.z = p.z;
    }
    
    void adjustMaxPoint(Vector3f p)
    {
        if (p.x > pmax.x) pmax.x = p.x;
        if (p.y > pmax.y) pmax.y = p.y;
        if (p.z > pmax.z) pmax.z = p.z;
    }

    foreach(object; objects)
    {
        adjustMinPoint(object.boundingBox.pmin);
        adjustMaxPoint(object.boundingBox.pmax);
    }
    
    return boxFromMinMaxPoints(pmin, pmax);
}

class BVHNode(T)
{
    public:
    T[] objects;
    AABB aabb;
    uint userData = 0;
    BVHNode!T[2] child;

    this(T[] objs)
    {
        objects = objs;
        aabb = boxFromObjects(objects);
    }

    void traverse(SceneNode object, void delegate(T) func)
    {
        Vector3f cn;
        float pd;
        if (aabb.intersectsSphere(object.boundingSphere, cn, pd))
        {
            if (child[0] !is null)
                child[0].traverse(object, func);
            if (child[1] !is null)
                child[1].traverse(object, func);

            foreach(obj; objects)
                func(obj);
        }
    }

    void traverseRay(Ray ray, void delegate(T) func)
    {
        float it = 0.0f;
        if (aabb.intersectsSegment(ray.p0, ray.p1, it))
        {
            if (child[0] !is null)
                child[0].traverseRay(ray, func);
            if (child[1] !is null)
                child[1].traverseRay(ray, func);

            foreach(obj; objects)
                func(obj);
        }
    }

    void traverse(void delegate(BVHNode!T) func)
    {
        if (child[0] !is null)
            child[0].traverse(func);
        if (child[1] !is null)
            child[1].traverse(func);

        func(this);
    }
	
    void drawActiveHierarchy(SceneNode object)
    {
        Vector3f cn;
        float pd;
        if (aabb.intersectsSphere(object.boundingSphere, cn, pd))
        {
            if (child[0] !is null)
                child[0].drawActiveHierarchy(object);
            if (child[1] !is null)
                child[1].drawActiveHierarchy(object);

            aabb.draw();
        }
    }
}

// TODO:
// - support multithreading (2 children = 2 threads)
// - add ESC (Early Split Clipping)

enum Heuristic
{
    HMA, // Half Main Axis
    SAH, // Surface Area Heuristic
    // TODO:
    //ESC  // Early Split Clipping
}

/*
 *  Type T should implement the following read-only properties:
 *  AABB boundingBox
 */
final class BVHTree(T)
{
    public:
    
    BVHNode!T root;

    this(T[] objects, 
         uint maxObjectsPerNode = 8,
         Heuristic splitHeuristic = Heuristic.SAH)
    {
        root = construct(objects, maxObjectsPerNode, splitHeuristic);
    }
         
    BVHNode!T construct(
         T[] objects, 
         uint maxObjectsPerNode,
         Heuristic splitHeuristic)
    {
        AABB box = boxFromObjects(objects);
        
        SplitPlane sp;
        if (splitHeuristic == Heuristic.HMA)
            sp = getHalfMainAxisSplitPlane(objects, box);
        else if (splitHeuristic == Heuristic.SAH)
            sp = getSAHSplitPlane(objects, box);
        else
            assert(0, "BVH: unsupported split heuristic");
            
        auto boxes = boxSplitWithPlane(box, sp);

        T[] leftObjects;
        T[] rightObjects;
    
        foreach(obj; objects)
        {
            if (boxes[0].intersectsAABB(obj.boundingBox))
                leftObjects ~= obj;
            else if (boxes[1].intersectsAABB(obj.boundingBox))
                rightObjects ~= obj;
        }
    
        BVHNode!T node = new BVHNode!T(objects);

        if (objects.length <= maxObjectsPerNode)
            return node;
        
        if (leftObjects.length > 0 || rightObjects.length > 0)
            node.objects = [];

        if (leftObjects.length > 0)
            node.child[0] = construct(leftObjects, maxObjectsPerNode, splitHeuristic);
        else
            node.child[0] = null;
    
        if (rightObjects.length > 0)
            node.child[1] = construct(rightObjects, maxObjectsPerNode, splitHeuristic);
        else
            node.child[1] = null;

        return node;    
    }
    
    private:
    
    SplitPlane getHalfMainAxisSplitPlane(ref T[] objects, ref AABB box)
    {
        Axis axis = boxGetMainAxis(box);
        return boxGetSplitPlaneForAxis(box, axis);
    }
    
    SplitPlane getSAHSplitPlane(ref T[] objects, ref AABB box)
    {
        Axis axis = boxGetMainAxis(box);
        
        float minAlongSplitPlane = box.pmin[axis];
        float maxAlongSplitPlane = box.pmax[axis];
        
        float bestSAHCost = float.nan;
        float bestSplitPoint = float.nan;

        int iterations = 12;
        foreach (i; 0..iterations)
        {
            float valueOfSplit = minAlongSplitPlane + 
                               ((maxAlongSplitPlane - minAlongSplitPlane) / (iterations + 1.0f) * (i + 1.0f));

            SplitPlane SAHSplitPlane = SplitPlane(valueOfSplit, axis);
            auto boxes = boxSplitWithPlane(box, SAHSplitPlane);

            uint leftObjectsLength = 0;
            uint rightObjectsLength = 0;

            foreach(obj; objects)
            {
                if (boxes[0].intersectsAABB(obj.boundingBox))
                    leftObjectsLength++;
                else if (boxes[1].intersectsAABB(obj.boundingBox))
                    rightObjectsLength++;
            }

            if (leftObjectsLength > 0 && rightObjectsLength > 0)
            {
                float SAHCost = getSAHCost(boxes[0], leftObjectsLength, 
                                           boxes[1], rightObjectsLength, box);

                if (bestSAHCost.isNaN || SAHCost < bestSAHCost)
                {
                    bestSAHCost = SAHCost;
                    bestSplitPoint = valueOfSplit;
                }
            }
        }
        
        return SplitPlane(bestSplitPoint, axis);
    }
    
    float getSAHCost(AABB leftBox, uint numLeftObjects, 
                     AABB rightBox, uint numRightObjects,
                     AABB parentBox)
    {
        return getVolumeFraction(leftBox, parentBox) * numLeftObjects
             + getVolumeFraction(rightBox, parentBox) * numRightObjects;
    }

    float getVolumeFraction(AABB box, AABB parentBox)
    {
        return getSurfaceArea(box) / getSurfaceArea(parentBox);
    }

    float getSurfaceArea(AABB bbox)
    {
        float width = bbox.pmax.x - bbox.pmin.x;
        float height = bbox.pmax.y - bbox.pmin.y;
        float depth = bbox.pmax.z - bbox.pmin.z;
        return 2.0f * (width * height + width * depth + height * depth);
    }
}
