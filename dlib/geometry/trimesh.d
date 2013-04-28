module dlib.geometry.trimesh;

private
{
    import std.math;
    import dlib.math.vector;   
    import dlib.geometry.triangle;
}

// TODO:
// - genTangents
struct TriMesh
{
    Vector3f[] vertices;
    Vector3f[] normals;
    Vector3f[] tangents;
    Vector2f[] texcoords1;
    Vector2f[] texcoords2;
    uint numTexCoords = 0;
    
    //alias uint[3] Index;
    struct Index
    {
        uint a, b, c;
    }
    
    struct FaceGroup
    {
        Index[] indices;
        int materialIndex;
    }
    
    FaceGroup[] facegroups;
    
    Triangle getTriangle(uint facegroupIndex, uint triIndex)
    {
        Triangle tri;
        Index triIdx = facegroups[facegroupIndex].indices[triIndex];
        
        tri.v[0] = vertices[triIdx.a];
        tri.v[1] = vertices[triIdx.b];
        tri.v[2] = vertices[triIdx.c];
        
        tri.n[0] = normals[triIdx.a];
        tri.n[1] = normals[triIdx.b];
        tri.n[2] = normals[triIdx.c];
        
        if (numTexCoords > 0)
        {
            tri.t1[0] = texcoords1[triIdx.a];
            tri.t1[1] = texcoords1[triIdx.b];
            tri.t1[2] = texcoords1[triIdx.c];
        
            if (numTexCoords > 1)
            {
                tri.t2[0] = texcoords2[triIdx.a];
                tri.t2[1] = texcoords2[triIdx.b];
                tri.t2[2] = texcoords2[triIdx.c];
            }
        }
        
        tri.normal = normal(tri.v[0], tri.v[1], tri.v[2]);
        
        tri.barycenter = (tri.v[0] + tri.v[1] + tri.v[2]) / 3;
        
        tri.d = (tri.v[0].x * tri.normal.x + 
                 tri.v[0].y * tri.normal.y + 
                 tri.v[0].z * tri.normal.z);

        tri.edges[0] = tri.v[1] - tri.v[0];
        tri.edges[1] = tri.v[2] - tri.v[1];
        tri.edges[2] = tri.v[0] - tri.v[2];
        
        tri.materialIndex = facegroups[facegroupIndex].materialIndex;
        
        return tri;
    }
    
    // Read-only triangle aggregate:
    // foreach(tri; mesh) ...
    int opApply(int delegate(ref Triangle) dg)
    {
        int result = 0;
        for (uint fgi = 0; fgi < facegroups.length; fgi++)
        for (uint i = 0; i < facegroups[fgi].indices.length; i++)
        {
            Triangle tri = getTriangle(fgi, i);
            result = dg(tri);
            if (result)
                break;
        }
        return result;
    }

    /+
    void genTangents()
    {
        Vector3f[] sTan = new Vector3f[vertices.length];
        Vector3f[] tTan = new Vector3f[vertices.length];

        foreach(fg; faceGroup)
        foreach(triIndex; indices)
        {
            uint i = triIndex/3;
            uint i0 = tri.i0;
            uint i1 = tri.i1;
            uint i2 = tri.i2;

            Vector3f v0 = vertices[i0];
            Vector3f v1 = vertices[i1];
            Vector3f v2 = vertices[i2];

            Vector2f w0 = texcoords[i0];
            Vector2f w1 = texcoords[i1];
            Vector2f w2 = texcoords[i2];

            float x1 = v1.x - v0.x;
            float x2 = v2.x - v0.x;
            float y1 = v1.y - v0.y;
            float y2 = v2.y - v0.y;
            float z1 = v1.z - v0.z;
            float z2 = v2.z - v0.z;

            float s1 = w1[0] - w0[0];
            float s2 = w2[0] - w0[0];
            float t1 = w1[1] - w0[1];
            float t2 = w2[1] - w0[1];

            float r = (s1 * t2) - (s2 * t1);

	        // Prevent division by zero
            if (r == 0.0f)
	            r = 1.0f;

            float oneOverR = 1.0f / r;

            Vector3f sDir = Vector3f((t2 * x1 - t1 * x2) * oneOverR,
		                             (t2 * y1 - t1 * y2) * oneOverR,
		                             (t2 * z1 - t1 * z2) * oneOverR);
            Vector3f tDir = Vector3f((s1 * x2 - s2 * x1) * oneOverR,
		                             (s1 * y2 - s2 * y1) * oneOverR,
		                             (s1 * z2 - s2 * z1) * oneOverR);

	        sTan[i0] += sDir;
	        tTan[i0] += tDir;

	        sTan[i1] += sDir;
	        tTan[i1] += tDir;

	        sTan[i2] += sDir;
	        tTan[i2] += tDir;
        }

        tangents = new Vector3f[vertices.length];

        // Calculate vertex tangent
        foreach(i, ref tangent; tangents)
        {
            Vector3f n = normals[i];
            Vector3f t = sTan[i];

            // Gram-Schmidt orthogonalize
            tangent = (t - n * dot(n, t));
            tangent.normalize();

            // Calculate handedness
            if (dot(cross(n, t), tTan[i]) < 0.0f)
	        tangent = -tangent;
        }
    }
    +/
}
