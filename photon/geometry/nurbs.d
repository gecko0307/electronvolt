module photon.geometry.nurbs;

private
{
    import std.math;
    import derelict.opengl.gl;
    import dlib.math.vector;
}

struct BSplineBasis
{
    public:
    this (int numCtrlPoints, int degree, bool open)
    in
    {
        assert (numCtrlPoints >= 2, "BSplineBasis: invalid input (numCtrlPoints)");
        assert (1 <= degree && degree <= numCtrlPoints-1, "BSplineBasis: invalid input (degree)");
    }
    body
    {
        this.numCtrlPoints = numCtrlPoints;
        this.degree = degree;
        this.open = open;

        knots = new float[n + d + 1];

        float factor = 1.0f / (n - d);
        int i;
        if (open)
        {
            for (i = 0; i <= d; ++i)
                knots[i] = 0.0f;
            for (/**/; i < n; ++i)
                knots[i] = (i - d) * factor;
            for (/**/; i < knots.length; ++i)
                knots[i] = 1.0f;
        }
        else
        {
            for (i = 0; i < knots.length; ++i)
                knots[i] = (i - d) * factor;
        }

        mBD0 = allocate();
    }

    int getKey(float t)
    {
        if (open)
        {
            // Open splines clamp to [0,1].
            if (t <= 0.0f)
            {
                t = 0.0f;
                return degree;
            }
            else if (t >= 1.0f)
            {
                t = 1.0f;
                return numCtrlPoints - 1;
            }
        }
        else
        {
            // Periodic splines wrap to [0,1).
            if (t < 0.0f || t >= 1.0f)
                t -= floor(t);
        }

        int i;

        if (uniform)
            i = degree + cast(int)((numCtrlPoints - degree) * t);
        else
        {
            for (i = degree + 1; i <= numCtrlPoints; ++i)
                if (t < knots[i])
                    break;
            --i;
        }

        return i;
    }

    void compute(float t, uint order, out int minIndex, out int maxIndex)
    {
        assert (order <= 3, "BSplineBasis: only derivatives to third order supported");

        if (order >= 1)
        {
            if (mBD1 is null)
                mBD1 = allocate();
            if (order >= 2)
            {
                if (mBD2 is null)
                    mBD2 = allocate();
                if (order >= 3)
                {
                    if (mBD3 is null)
                        mBD3 = allocate();
                }
            }
        }

        int i = getKey(t);
        mBD0[0][i] = 1.0f;

        if (order >= 1)
        {
            mBD1[0][i] = 0.0f;
            if (order >= 2)
            {
                mBD2[0][i] = 0.0f;
                if (order >= 3)
                    mBD3[0][i] = 0.0f;
            }
        }

        float n0 = t - knots[i], n1 = knots[i+1] - t;
        float invD0, invD1;
        int j;
        for (j = 1; j <= degree; j++)
        {
            invD0 = 1.0f / (knots[i+j] - knots[i]);
            invD1 = 1.0f / (knots[i+1] - knots[i-j+1]);

            mBD0[j][i] = n0 * mBD0[j-1][i] * invD0;
            mBD0[j][i-j] = n1 * mBD0[j-1][i-j+1] * invD1;

            if (order >= 1)
            {
                mBD1[j][i] = (n0 * mBD1[j-1][i] + mBD0[j-1][i]) * invD0;
                mBD1[j][i-j] = (n1 * mBD1[j-1][i-j+1] - mBD0[j-1][i-j+1]) * invD1;

                if (order >= 2)
                {
                    mBD2[j][i] = (n0 * mBD2[j-1][i] + 2.0f * mBD1[j-1][i]) * invD0;
                    mBD2[j][i-j] = (n1 * mBD2[j-1][i-j+1] - 2.0f * mBD1[j-1][i-j+1]) * invD1;

                    if (order >= 3)
                    {
                        mBD3[j][i] = (n0 * mBD3[j-1][i] + 3.0f * mBD2[j-1][i]) * invD0;
                        mBD3[j][i-j] = (n1 * mBD3[j-1][i-j+1] - 3.0f * mBD2[j-1][i-j+1]) * invD1;
                    }
                }
            }
        }

        for (j = 2; j <= degree; ++j)
        {
            for (int k = i-j+1; k < i; ++k)
            {
                n0 = t - knots[k];
                n1 = knots[k+j+1] - t;
                invD0 = 1.0f/(knots[k+j] - knots[k]);
                invD1 = 1.0f/(knots[k+j+1] - knots[k+1]);

                mBD0[j][k] = n0 * mBD0[j-1][k] * invD0 + n1 * mBD0[j-1][k+1] * invD1;

                if (order >= 1)
                {
                    mBD1[j][k] = (n0 * mBD1[j-1][k] + mBD0[j-1][k]) * invD0 +
                                 (n1 * mBD1[j-1][k+1] - mBD0[j-1][k+1]) * invD1;
                    if (order >= 2)
                    {
                        mBD2[j][k] = (n0*mBD2[j-1][k] +
                                     2.0f*mBD1[j-1][k])*invD0 +
                                     (n1*mBD2[j-1][k+1] - 2.0f*mBD1[j-1][k+1])*invD1;
                        if (order >= 3)
                        {
                            mBD3[j][k] = (n0*mBD3[j-1][k] +
                                         3.0f*mBD2[j-1][k])*invD0 +
                                         (n1*mBD3[j-1][k+1] - 3.0f*
                                         mBD2[j-1][k+1])*invD1;
                        }
                    }
                }
            }
        }

        minIndex = i - degree;
        maxIndex = i;
    }

    float getD0(int i)
    {
        return mBD0[degree][i];
    }

    float getD1(int i)
    {
        return mBD1[degree][i];
    }

    float getD2(int i)
    {
        return mBD2[degree][i];
    }

    float getD3(int i)
    {
        return mBD3[degree][i];
    }

    public:
    float[] knots;
    bool open;
    bool uniform = true;
    int degree;
    int numCtrlPoints;

    private:
    alias degree d;
    alias numCtrlPoints n;

    float[][] mBD0;  // bd0[d+1][n+d+1]
    float[][] mBD1;  // bd1[d+1][n+d+1]
    float[][] mBD2;  // bd2[d+1][n+d+1]
    float[][] mBD3;  // bd3[d+1][n+d+1]

    float[][] allocate()
    {
        int numRows = degree + 1;
        int numCols = numCtrlPoints + degree;
        float[][] data = new float[][](numRows, numCols);
        foreach(d; data)
        foreach(v; d)
            v = 0.0f;
        return data;
    }
}

struct Nurbs
{
    this(Vector4f[] ctrlPoints)
    {
        assert (ctrlPoints.length >= 2, "BSplineBasis: invalid input (ctrlPoints)");
        this.ctrlPoints = ctrlPoints;
        basis = BSplineBasis(ctrlPoints.length, ctrlPoints.length-1, true);
    }

    Vector3f getPosition(float t)
    {
        Vector3f pos;
        get(t, &pos, null, null, null);
        return pos;
    }

    void get(float t, Vector3f* pos, Vector3f* der1, Vector3f* der2, Vector3f* der3)
    {
        int i, imin, imax;
        if (der3 !is null)
        {
            basis.compute(t, 0, imin, imax);
            basis.compute(t, 1, imin, imax);
            basis.compute(t, 2, imin, imax);
            basis.compute(t, 3, imin, imax);
        }
        else if (der2 !is null)
        {
            basis.compute(t, 0, imin, imax);
            basis.compute(t, 1, imin, imax);
            basis.compute(t, 2, imin, imax);
        }
        else if (der1 !is null)
        {
            basis.compute(t, 0, imin, imax);
            basis.compute(t, 1, imin, imax);
        }
        else  // pos
        {
            basis.compute(t, 0, imin, imax);
        }

        float tmp;

        // Compute position
        Vector3f X = Vector3f(0.0f, 0.0f, 0.0f);
        float w = 0.0f;
        for (i = imin; i <= imax; ++i)
        {
            tmp = basis.getD0(i) * ctrlPoints[i].w;
            X += tmp * ctrlPoints[i].xyz;
            w += tmp;
        }
        float invW = 1.0f / w;
        Vector3f P = invW * X;
        if (pos !is null)
            *pos = P;
        if ((der1 is null) && (der2 is null) && (der3 is null))
            return;

        // Compute first derivative.
        Vector3f XDer1 = Vector3f(0.0f, 0.0f, 0.0f);
        float wDer1 = 0.0f;
        for (i = imin; i <= imax; ++i)
        {
            tmp = basis.getD1(i) * ctrlPoints[i].w;
            XDer1 += tmp * ctrlPoints[i].xyz;
            wDer1 += tmp;
        }
        Vector3f PDer1 = invW * (XDer1 - wDer1 * P);
        if (der1 !is null)
            *der1 = PDer1;
        if ((der2 is null) && (der3 is null))
            return;

        // Compute second derivative.
        Vector3f XDer2 = Vector3f(0.0f, 0.0f, 0.0f);
        float wDer2 = 0.0f;
        for (i = imin; i <= imax; ++i)
        {
            tmp = basis.getD2(i) * ctrlPoints[i].w;
            XDer2 += tmp * ctrlPoints[i].xyz;
            wDer2 += tmp;
        }
        Vector3f PDer2 = invW * (XDer2 - 2.0f * wDer1 * PDer1 - wDer2 * P);
        if (der2 !is null)
            *der2 = PDer2;        if (der3 is null)
            return;

        // Compute third derivative.
        Vector3f XDer3 = Vector3f(0.0f, 0.0f, 0.0f);
        float wDer3 = 0.0f;
        for (i = imin; i <= imax; ++i)
        {
            tmp = basis.getD3(i) * ctrlPoints[i].w;
            XDer3 += tmp * ctrlPoints[i].xyz;
            wDer3 += tmp;
        }
        if (der3 !is null)
            *der3 = invW * (XDer3 - 3.0f * wDer1 * PDer2 
                    - 3.0f * wDer2 * PDer1 - wDer3 * P);
    }

    void draw(float step = 0.05f)
    {
        Vector3f num, last;
        float t;

        glDisable(GL_LIGHTING);
    
        glColor4ub(255, 255, 255, 255);
        glBegin(GL_LINES);

        last = ctrlPoints[0].xyz;
        num = last;

        //for (t = basis.knots[0]; t < basis.knots[$-1]; t += step)
        for (t = 0.0f; t < 1.0f + step; t += step)
        {
            num = getPosition(t);
            glVertex3f(last[0], last[1], last[2]);            glVertex3f(num[0], num[1], num[2]);	  
            last = num;
        }

        glEnd();
        glEnable(GL_LIGHTING);

        int i;
        glDisable(GL_LIGHTING);
        glColor4f(0.0,1.0,0.0,0.5);
        glBegin(GL_LINES);
        for (i = 0; i < ctrlPoints.length - 1; i++)
        {
            glVertex3f((ctrlPoints[i])[0], (ctrlPoints[i])[1], (ctrlPoints[i])[2]);
            glVertex3f((ctrlPoints[i + 1])[0], (ctrlPoints[i + 1])[1], (ctrlPoints[i + 1])[2]);
        }
        glEnd();
        glEnable(GL_LIGHTING);  
    }

    private:
    BSplineBasis basis;
    Vector4f[] ctrlPoints;
}

