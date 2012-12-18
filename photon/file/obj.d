module photon.file.obj;

private
{
    import std.c.stdlib;
    import std.c.stdio;
    import std.c.string;

    import std.stream;
	import std.string;
	
	import derelict.opengl.gl;
	
	import dlib.math.vector;
	
	import photon.geometry.triangle;
	import photon.geometry.spheretri;
	import photon.mesh.trimesh;
}

struct OBJMesh
{
    struct Face
    {
        uint sides = 3; 
        uint[4] v;
        uint[4] vt;
        uint[4] vn;
        uint[4] vtg;
        bool haveTexCoords = true;
        bool haveNormals = true;
    }

    Vector3f[] vertices;
    Vector3f[] normals;
    Vector2f[] texcoords;
    Vector3f[] tangents;
    Face[] faces;

    TriMesh toTriMesh()
    {
        TriMesh mesh;
        //uint currentIndex = 0;

        foreach(face; faces)
        {
            if (face.sides != 3)
                throw new Exception("OBJMesh.toTriMesh: face is not a triangle");
            if (!face.haveTexCoords)
                throw new Exception("OBJMesh.toTriMesh: face have no texcoords assigned");
            if (!face.haveNormals)
                throw new Exception("OBJMesh.toTriMesh: face have no normals assigned");

            uint[3] indices;

            foreach(i; 0..3)
            {
                mesh.vertices  ~= vertices[face.v[i] - 1];
                mesh.normals   ~= normals[face.vn[i] - 1];
                mesh.texcoords ~= texcoords[face.vt[i] - 1];
                indices[i] = mesh.vertices.length-1;
            }

            mesh.indices ~= TriIndex(indices[0], indices[1], indices[2]);
        }

        return mesh;
    }

    GLuint toDisplayList()
    {
        GLuint displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);

        foreach(face; faces)
        {
            if (face.sides == 3) glBegin(GL_TRIANGLES);
            else glBegin(GL_QUADS);
            if (texcoords) glTexCoord2fv(texcoords[face.vt[0]-1].arrayof.ptr);
            if (normals) glNormal3fv(normals[face.vn[0]-1].arrayof.ptr);
            if (vertices) glVertex3fv(vertices[face.v[0]-1].arrayof.ptr);

            if (texcoords) glTexCoord2fv(texcoords[face.vt[1]-1].arrayof.ptr);
            if (normals) glNormal3fv(normals[face.vn[1]-1].arrayof.ptr);
            if (vertices) glVertex3fv(vertices[face.v[1]-1].arrayof.ptr);

            if (texcoords) glTexCoord2fv(texcoords[face.vt[2]-1].arrayof.ptr);
            if (normals) glNormal3fv(normals[face.vn[2]-1].arrayof.ptr);
            if (vertices) glVertex3fv(vertices[face.v[2]-1].arrayof.ptr);

            if (face.sides == 4)
            {
                if (texcoords) glTexCoord2fv(texcoords[face.vt[3]-1].arrayof.ptr);
                if (normals) glNormal3fv(normals[face.vn[3]-1].arrayof.ptr);
                if (vertices) glVertex3fv(vertices[face.v[3]-1].arrayof.ptr);
            }
            glEnd();
        }

        glEndList();

        return displayList;
    }

    bool intersectsSphere(
        Vector3f center, 
        float radius, 
        ref IntersectionTestResult intr)
    {
        bool result = false;

        foreach(face; faces)
        {
            if (face.sides == 3)
            {
                Triangle tri;

                tri.v[0] = vertices[face.v[0]-1];
                tri.v[1] = vertices[face.v[1]-1];
                tri.v[2] = vertices[face.v[2]-1];

                tri.normal = normal(tri.v[0], tri.v[1], tri.v[2]);

                tri.d = (tri.v[0].x * tri.normal.x + 
                         tri.v[0].y * tri.normal.y + 
                         tri.v[0].z * tri.normal.z);

                tri.edges[0] = tri.v[1] - tri.v[0];
                tri.edges[1] = tri.v[2] - tri.v[1];
                tri.edges[2] = tri.v[0] - tri.v[2];

                result = result || testSphereVsTriangle(center, radius, intr, tri);
            }
        }

        return result;
    }
}

OBJMesh loadMeshFromOBJ(string filename)
{   
    OBJMesh mesh;

    auto f = new std.stream.File(filename, FileMode.In);
    while(!f.eof)
    {
        Vector3f v, vn;
        Vector2f vt;
        OBJMesh.Face face;

        auto line = f.readLine();

        // Parse vertex
        if (sscanf(toStringz(line), "v %f %f %f", &v[0], &v[1], &v[2]) == 3)
        {
            mesh.vertices ~= v;
        }
        // Parse vertex normal
        else if (sscanf(toStringz(line), "vn %f %f %f", &vn[0], &vn[1], &vn[2]) == 3)
        {
            mesh.normals ~= vn;
        }
        // Parse vertex texcoord
        else if (sscanf(toStringz(line), "vt %f %f", &vt[0], &vt[1]) == 2)
        {
            mesh.texcoords ~= vt;
        }
        // Parse face
        else if (sscanf(toStringz(line), "f %d/%d/%d %d/%d/%d %d/%d/%d %d/%d/%d", 
                 &face.v[0], &face.vt[0], &face.vn[0],
                 &face.v[1], &face.vt[1], &face.vn[1],
                 &face.v[2], &face.vt[2], &face.vn[2],
                 &face.v[3], &face.vt[3], &face.vn[3]) == 12)
        {
            face.sides = 4;
            mesh.faces ~= face;
        }
        else if (sscanf(toStringz(line), "f %d/%d/%d %d/%d/%d %d/%d/%d", 
                 &face.v[0], &face.vt[0], &face.vn[0],
                 &face.v[1], &face.vt[1], &face.vn[1],
                 &face.v[2], &face.vt[2], &face.vn[2]) == 9)
        {
            face.sides = 3;
            mesh.faces ~= face;
        }
        else if (sscanf(toStringz(line), "f %d//%d %d//%d %d//%d %d//%d", 
                 &face.v[0], &face.vn[0],
                 &face.v[1], &face.vn[1],
                 &face.v[2], &face.vn[2],
                 &face.v[3], &face.vn[3]) == 8)
        {
            face.sides = 4;
            face.haveTexCoords = false;
            mesh.faces ~= face;
        }
        else if (sscanf(toStringz(line), "f %d//%d %d//%d %d//%d", 
                 &face.v[0], &face.vn[0],
                 &face.v[1], &face.vn[1],
                 &face.v[2], &face.vn[2]) == 6)
        {
            face.sides = 3;
            face.haveTexCoords = false;
            mesh.faces ~= face;
        }
        else if (sscanf(toStringz(line), "f %d %d %d", 
                 &face.v[0], 
                 &face.v[1], 
                 &face.v[2]) == 3)
        {
            face.sides = 3;
            face.haveTexCoords = false;
            face.haveNormals = false;
            mesh.faces ~= face;
        }
        else if (sscanf(toStringz(line), "f %d %d %d %d", 
                 &face.v[0], 
                 &face.v[1], 
                 &face.v[2], 
                 &face.v[3]) == 4)
        {
            face.sides = 4;
            face.haveTexCoords = false;
            face.haveNormals = false;
            mesh.faces ~= face;
        }
    }

    f.close();

    return mesh;
}
