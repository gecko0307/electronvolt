module dlib.geometry.obb;

private
{
    import dlib.math.vector;
    import dlib.math.matrix3x3;
    import dlib.math.matrix4x4;
}

struct OBB
{
    Vector3f extent;
    Matrix4x4f transform;
    
    this(Vector3f position, Vector3f size)
    {
        transform = identityMatrix4x4f();
        center = position;
        extent = size;
    }
    
    @property
    {
        Vector3f center()
        {
            return transform.translation;
        }

        Vector3f center(Vector3f v)
        body
        {
            transform.translation = v;
            return v;
        }
    }
    
    @property Matrix3x3f orient()
    {
        return matrix4x4to3x3(transform);
    }
}
