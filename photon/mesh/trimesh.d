module photon.mesh.trimesh;

private
{
    import dlib.math.vector;
}

struct TriIndex
{
    uint i0;
    uint i1;
    uint i2;
}

struct TriMesh
{
    Vector3f[] vertices;
    Vector3f[] normals;
    Vector2f[] texcoords;
    Vector3f[] tangents;
    TriIndex[] indices;
/*
    void removeDuplicates()
    {
        Vector3f newVertices[];
        Vector2f newTexcoords[];
        uint[] newIndices = new uint[indices.length];

        int getDuplicateIndex(int vi)
        {
            Vector3f vert = vertices[vi];
            Vector2f texc = texcoords[vi];

            foreach(i, v; newVertices)
            {
                if (v == vert && newTexcoords[i] == texc)
                    return i;
            }

            return -1;
        }

        int addVertex(int vi)
        {
            int dupli = getDuplicateIndex(vi);
            if (dupli < 0)
            {
                newVertices ~= vertices[vi];
                newTexcoords ~= texcoords[vi];
                // newNormals ~=
                return newVertices.length - 1;
            }
            else return dupli;
        }

        for(int i = 0; i < indices.length; i += 3)
        {
            uint i0 = indices[i + 0];
            uint i1 = indices[i + 1];
            uint i2 = indices[i + 2];

            newIndices[i + 0] = addVertex(i0);
            newIndices[i + 1] = addVertex(i1);
            newIndices[i + 2] = addVertex(i2);
        }
    }
*/
    void genTangents()
    {
        Vector3f[] sTan = new Vector3f[vertices.length];
        Vector3f[] tTan = new Vector3f[vertices.length];

        foreach(triIndex, tri; indices)
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
}
