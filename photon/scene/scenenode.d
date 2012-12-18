module photon.scene.scenenode;

private
{
    import std.algorithm;
    import std.variant;

    import derelict.opengl.gl;

    import dlib.math.utils;
    import dlib.math.vector;
    import dlib.math.matrix4x4;

    import photon.core.drawable;
    import photon.core.modifier;
    import photon.geometry.aabb;
    import photon.geometry.bsphere;
}

abstract class SceneNode: Drawable, Modifier
{
    public:

    this(SceneNode par = null)
    {
        position = Vector3f(0.0f, 0.0f, 0.0f);
        rotation = Vector3f(0.0f, 0.0f, 0.0f);
        scaling = Vector3f(1.0f, 1.0f, 1.0f);
        positionPrevious = Vector3f(0.0f, 0.0f, 0.0f);

        localMatrix = Matrix4x4f(); // identity
        localMatrixPtr = &localMatrix;

        parent = par;
        if (parent !is null)
            parent.addChild(this);
    }

    void addChild(SceneNode child)
    {
        children ~= child;
    }

    void removeChild(SceneNode child)
    {
        int index = getChildIndex(child);
        if (index >= 0)
            children = children.remove(index);
    }

    int getChildIndex(SceneNode child)
    {
        foreach(i, node; children)
        {
            if (node == child)
                return i;
        }
        return -1;
    }

    void bind(double delta)
    {
        localMatrix = translationMatrix(position);
        positionPrevious = position;

        localMatrix *= rotationMatrix(Axis.x, degtorad(rotation.x));
        localMatrix *= rotationMatrix(Axis.y, degtorad(rotation.y));
        localMatrix *= rotationMatrix(Axis.z, degtorad(rotation.z));

        localMatrix *= scaleMatrix(scaling);

        glPushMatrix();
        glMultMatrixf(localMatrixPtr.arrayof.ptr);
    }

    void unbind()
    {
        glPopMatrix();
    }

    void bindAsCamera(double delta)
    {
        glPushMatrix();

        //auto cameraMatrix = Matrix4x4f(*localMatrixPtr);
        //cameraMatrix.transpose();
        //cameraMatrix.invert();
        //glMultMatrixf(cameraMatrix.arrayof.ptr);

        glRotatef(-rotation.z, 0.0f, 0.0f, 1.0f);
        glRotatef(-rotation.y, 0.0f, 1.0f, 0.0f);
        glRotatef(-rotation.x, 1.0f, 0.0f, 0.0f);
        glTranslatef(-position.x, -position.y, -position.z);

        if (parent !is null)
            parent.bindAsCamera(delta);
    }

    void unbindAsCamera()
    {
        if (parent !is null)
            parent.unbindAsCamera();

        glPopMatrix();
    }

    void draw(double delta)
    {
        bind(delta);

        foreach(child; children)
        {
            //child.visible = visible;
            child.draw(delta);
        }
        
        foreach(m; modifiers)
            m.bind(delta);

        if (visible && (parent !is null && parent.visible))
        {
            render(delta);           
        }

        foreach(m; modifiers)
            m.unbind();

        unbind();
    }

    void render(double delta) // override me
    {
    }

    void free()
    {
        if (children.length > 0)
        {
            clean();
            if (parent !is null)
                parent.removeChild(this);
            parent = null;
        }
    }

    void clean() // override me
    {
    }

    void translate(Vector3f vec)
    {
        position += vec;
    }

    void move(float speed)
    {
        position += localMatrix.forward * speed;
    }
    
    void strafe(float speed)
    {
        position += localMatrix.right * speed;
    }
    
    void lift(float speed)
    {
        position += localMatrix.up * speed;
    }

    void moveToPoint(Vector3f pt, float speed)
    {
        Vector3f dir = pt - position;
        dir.normalize();

        float dist = distance(position, pt);
        if (dist != 0.0f)
        {
            if (dist >= speed)
            {
                position += dir * speed;
            }
            else
            {
                position += dir * dist;
            }
        }
    }
    
    void slide(Vector3f contactNormal, float penetrationDepth)
    {
        position += contactNormal * penetrationDepth; 
        Vector3f trans = velocity - contactNormal * (dot(velocity, contactNormal));
        translate(trans * 0.25f);
    }

    bool isMoving()
    {
        return (!velocity.isZero);
    }

    void rotate(Vector3f vec)
    {
        rotation += vec;
    }

    void pitch(float angle)
    {
        rotation.x += angle;
    }

    void turn(float angle)
    {
        rotation.y += angle;
    }

    void roll(float angle)
    {
        rotation.z += angle;
    }
    
    void scale(Vector3f factor)
    {
        scaling += factor;
    }

    Vector3f position;
    Vector3f rotation;
    Vector3f scaling;
    
    @property Vector3f velocity()
    {
        return position - positionPrevious;
    }

    Vector3f positionPrevious;

    @property Vector3f absolutePosition()
    {
        if (parent is null)
            return position;
        else
            return parent.absolutePosition + position;
    }

    bool visible = true;

    Matrix4x4f localMatrix;
    Matrix4x4f* localMatrixPtr;

    @property Matrix4x4f absoluteMatrix()
    {
        if (parent !is null)
            return parent.absoluteMatrix * (*localMatrixPtr);
        else
            return *localMatrixPtr;
    }

    @property AABB boundingBox() // override me
    {
        return AABB(absolutePosition, scaling);
    }

    @property BSphere boundingSphere() // override me
    {
        return BSphere(absolutePosition, scaling.x);
    }

    uint type = 0;
    float mass = -1.0f;
    float bounce = 0.0f;

    @property SceneNode[] childrenNodes()
    {
        return children;
    }

    //protected:
    
    SceneNode parent = null;
    SceneNode[] children;
    public Modifier[] modifiers;
}

