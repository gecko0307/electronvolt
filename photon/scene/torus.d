module photon.scene.torus;

private
{
    import std.math;
    import derelict.opengl.gl;

    import photon.scene.scenenode;
    import photon.geometry.aabb;
}

final class Torus: SceneNode
{
    //private:
    float[] vertices;
    float[] normals;
    uint[] indices;

    //public:
    float radius;
    float innerRadius;

    this (float rad, float inner_rad, uint slices, uint inner_slices, SceneNode par = null)
    {
        super(par);

        radius = rad;
        innerRadius = inner_rad;

        float u_step = 2 * PI / (slices - 1);
        float v_step = 2 * PI / (inner_slices - 1);
        float u = 0.0f;

        foreach(i; 0..slices)
        {
            float cos_u = cos(u);
            float sin_u = sin(u);
            float v = 0.0f;

            foreach(j; 0..inner_slices)
            {
                float cos_v = cos(v);
                float sin_v = sin(v);

                float d = (radius + innerRadius * cos_v);
                float x = d * cos_u;
                float y = d * sin_u;
                float z = innerRadius * sin_v;

                float nx = cos_u * cos_v;
                float ny = sin_u * cos_v;
                float nz = sin_v;

                vertices ~= [x, y, z];
                normals ~= [nx, ny, nz];
                v += v_step;
            }

            u += u_step;
        }

        foreach(i; 0..slices - 1)
        {
            foreach(j; 0..inner_slices - 1)
            {
                uint p = i * inner_slices + j;
                indices ~= [p, p + inner_slices, p + inner_slices + 1];
                indices ~= [p, p + inner_slices + 1, p + 1];
            }
        }
    }

    override void render(double delta)
    {
        if (vertices.length && 
            normals.length && 
            indices.length)
        {
            glEnableClientState(GL_VERTEX_ARRAY);
            glEnableClientState(GL_NORMAL_ARRAY);

            glVertexPointer(3, GL_FLOAT, 0, vertices.ptr);
            glNormalPointer(GL_FLOAT, 0, normals.ptr);
            glDrawElements(GL_TRIANGLES, indices.length, GL_UNSIGNED_INT, indices.ptr);

            glDisableClientState(GL_NORMAL_ARRAY);
            glDisableClientState(GL_VERTEX_ARRAY);
        }
    }

    @property AABB boundingBox()
    {
        return AABB(position, radius * scaling);
    }
	
    override void clean()
    {
        delete vertices;
        delete normals;
        delete indices;
    }
}

