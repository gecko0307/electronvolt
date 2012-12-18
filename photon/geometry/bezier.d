module photon.geometry.bezier;

private
{
    import derelict.opengl.gl;
	
    import dlib.math.vector;
}

T bezier(T) (T A, T B, T C, T D, T t)
{
    T s = 1.0 - t;
    T AB = A * s + B * t;
    T BC = B * s + C * t;
    T CD = C * s + D * t;
    T ABC = AB * s + CD * t;
    T BCD = BC * s + CD * t;
    return ABC * s + BCD * t;
}

Vector2f bezierCalcPoint2D(Vector2f a, Vector2f b, Vector2f c, Vector2f d, float t)
{
    return Vector2f
    (
        bezier(a.x, b.x, c.x, d.x, t),
        bezier(a.y, b.y, c.y, d.y, t)
    );
}

struct BezierCurve3D
{
    Vector3f a;
    Vector3f b;
    Vector3f c;
    Vector3f d;

    Vector3f calcPoint(float t)
    {
        return Vector3f
        (
            bezier(a.x, b.x, c.x, d.x, t),
            bezier(a.y, b.y, c.y, d.y, t),
            bezier(a.z, b.z, c.z, d.z, t)
        );
    }

    void draw(float step = 0.05f)
    {
        glDisable(GL_LIGHTING);
        glColor4f(1.0, 1.0, 1.0, 1.0f);
        glLineWidth(1.0f);
        glBegin(GL_LINE_STRIP);
        float t = 0.0f;
        while (t < 1.0f)
        {
            Vector3f pt = calcPoint(t);
            glVertex3fv(pt.arrayof.ptr);
            t += step;
        }
        Vector3f pt = calcPoint(1.0f);
        glVertex3fv(pt.arrayof.ptr);
        glEnd();

        glBegin(GL_POINTS);
        t = 0.0f;
        while (t < 1.0f)
        {
            pt = calcPoint(t);
            glVertex3fv(pt.arrayof.ptr);
            t += step;
        }
        pt = calcPoint(1.0f);
        glVertex3fv(pt.arrayof.ptr);
        glEnd();
        glEnable(GL_LIGHTING);
    }
}

struct BezierNode
{
    Vector3f left;
    Vector3f center;
    Vector3f right;
    bool symmetric = true;

    void setLeft(Vector3f v)
    {
        left = v;
        if (symmetric)
        {
            Vector3f vecToCenter = left - center;
            right = -vecToCenter;
        }
    }

    void setRight(Vector3f v)
    {
        right = v;
        if (symmetric)
        {
            Vector3f vecToCenter = right - center;
            left = -vecToCenter;
        }
    }
}

struct BezierSpline
{
    BezierNode[] nodes;

    void drawLine(Vector3f a, Vector3f b)
    {
        glDisable(GL_LIGHTING);
        glColor4f(0.0, 1.0, 0.0, 1.0f);
        glLineWidth(1.0f);
        glBegin(GL_LINE_STRIP);
            glVertex3fv(a.arrayof.ptr);
            glVertex3fv(b.arrayof.ptr);
        glEnd();
        glEnable(GL_LIGHTING);
    }

    void drawPoint(Vector3f a)
    {
        glDisable(GL_LIGHTING);
        glColor4f(0.0, 1.0, 0.0, 1.0f);
        glPointSize(6.0f);
        glBegin(GL_POINTS);
            glVertex3fv(a.arrayof.ptr);
        glEnd();
        glEnable(GL_LIGHTING);
    }

    void draw(float step = 1.0f/12.0f)
    {
        glPushMatrix();
        if (nodes.length < 2)
            return;
        for(int i = 0; i < nodes.length-1; i++)
        {
            BezierNode* n = &nodes[i];
            BezierNode* next_n = &nodes[i+1];

            BezierCurve3D curve;
            curve.a = n.center;
            curve.b = n.right;
            curve.c = next_n.left;
            curve.d = next_n.center;

            curve.draw(step);

            drawLine(n.left, n.center);
            drawLine(n.center, n.right);
            drawPoint(n.left);
            drawPoint(n.center);
            drawPoint(n.right);
        }

        drawLine(nodes[$-1].left, nodes[$-1].center);
        drawLine(nodes[$-1].center, nodes[$-1].right);
        drawPoint(nodes[$-1].left);
        drawPoint(nodes[$-1].center);
        drawPoint(nodes[$-1].right);
        glPopMatrix();
    }

    BezierNode* addNode(BezierNode n)
    {
        nodes ~= n;
        return &nodes[$-1];
    }
}


