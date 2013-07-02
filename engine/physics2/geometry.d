module engine.physics2.geometry;

import std.math;

import dlib.math.vector;
import dlib.math.matrix4x4;
import dlib.math.matrix3x3;
import dlib.math.quaternion;
import dlib.math.utils;
import dlib.geometry.sphere;

/*
 * Convex geometry classes
 */

enum GeomType
{
    Undefined,
    Sphere,
    Box,
    Cylinder,
    Triangle
}

abstract class Geometry
{
    GeomType type = GeomType.Undefined;
    Matrix4x4f transformation;
    
    this()
    {
        transformation = identityMatrix4x4f();
    }
    
    void setTransformation(Vector3f position, Quaternionf orientation)
    {
        transformation = translationMatrix(position);
        transformation *= orientation.toMatrix();
    }
    
    Vector3f axis(int row)
    {
        float x, y, z;
    
        if (row == 0)
        {
            x = transformation.m11;
            y = transformation.m12;
            z = transformation.m13;
        }
        else if (row == 1)
        {
            x = transformation.m21;
            y = transformation.m22;
            z = transformation.m23;
        }
        else if (row == 2)
        {
            x = transformation.m31;
            y = transformation.m32;
            z = transformation.m33;
        }
        else if (row == 3)
        {
            x = transformation.tx;
            y = transformation.ty;
            z = transformation.tz;
        }

        return Vector3f(x, y, z);
    }
    
    @property Vector3f position()
    {
        return transformation.translation;
    }

    Vector3f supportPoint(Vector3f dir)
    {
        return Vector3f(0.0f, 0.0f, 0.0f);
    }
    
    float inertiaMoment(float mass)
    {
        return mass;
    }
    
    @property Sphere boundingSphere()
    {
        return Sphere(position, 1.0f);
    }
}

class GeomSphere: Geometry
{
    float radius;
    
    this(float r)
    {
        super();
        type = GeomType.Sphere;
        radius = r;
    }

    override Vector3f supportPoint(Vector3f dir)
    {
        return dir.normalized * radius;
    }
    
    override float inertiaMoment(float mass)
    {
        return 2.0f / 5.0f * mass * radius * radius;
    }
    
    override @property Sphere boundingSphere()
    {
        return Sphere(position, radius);
    }
}

class GeomBox: Geometry
{
    Vector3f halfSize;
    
    this(Vector3f hsize)
    {
        super();
        type = GeomType.Box;
        halfSize = hsize;
    }

    override Vector3f supportPoint(Vector3f dir)
    {
        Vector3f result;
        result.x = sign(dir.x) * halfSize.x;
        result.y = sign(dir.y) * halfSize.y;
        result.z = sign(dir.z) * halfSize.z;
        return result;
    }
    
    override @property Sphere boundingSphere()
    {
        return Sphere(position, halfSize.length);
    }
}

class GeomCylinder: Geometry
{
    float height;
    float radius;
    
    this(float h, float r)
    {
        super();
        type = GeomType.Cylinder;
        height = h;
        radius = r;
    }

    override Vector3f supportPoint(Vector3f dir)
    {
        Vector3f result;
        float sigma = sqrt((dir.x * dir.x + dir.z * dir.z));

        if (sigma > 0.0f)
        {
            result.x = dir.x / sigma * radius;
            result.y = sign(dir.y) * height * 0.5f;
            result.z = dir.z / sigma * radius;
        }
        else
        {
            result.x = 0.0f;
            result.y = sign(dir.y) * height * 0.5f;
            result.z = 0.0f;
        }
        
        return result;
    }
    
    // TODO: boundingSphere
}

class GeomTriangle: Geometry
{
    Vector3f[3] v;
    
    this(Vector3f a, Vector3f b, Vector3f c)
    {
        super();
        type = GeomType.Triangle;
        v[0] = a;
        v[1] = b;
        v[2] = c;
    }

    override Vector3f supportPoint(Vector3f dir)
    {
        float dota = dir.dot(v[0]);
        float dotb = dir.dot(v[1]);
        float dotc = dir.dot(v[2]);
    
        if (dota > dotb)
        {
            if (dotc > dota)
                return v[2];
            else
                return v[0];
        }
        else
        {
            if (dotc > dotb)
                return v[2];
            else
                return v[1];
        }
    }
    
    // TODO: boundingSphere
}
