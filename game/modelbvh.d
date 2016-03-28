module game.modelbvh;

import dlib.core.memory;
import dlib.container.array;
import dlib.math.matrix;
import dlib.geometry.triangle;

import dgl.graphics.mesh;
import dgl.asset.dgl2;

import dmech.bvh;

// TODO: This function is total hack,
// need to rewrite BVH module to handle Triangle ranges,
// and add a method to DGLResource that will lazily return 
// transformed triangles for entities.
BVHTree!Triangle modelBVH(DGLResource model)
{
    DynamicArray!Triangle tris;

    foreach(name, e; model.entitiesByName)
    {
        if (e.type == 0)
        {
            if ("ghost" in e.props)
            {
                if (e.props["ghost"].toBool)
                    continue;
            }

            Matrix4x4f mat = e.transformation;

            auto mesh = cast(Mesh)e.model;

            if (mesh is null)
                continue;

            foreach(fgroup; mesh.fgroups.data)
            foreach(tri; fgroup.tris.data)
            {
                Triangle tri2 = tri;
                tri2.v[0] = tri.v[0] * mat;
                tri2.v[1] = tri.v[1] * mat;
                tri2.v[2] = tri.v[2] * mat;
                tri2.normal = e.rotation.rotate(tri.normal);
                tri2.barycenter = (tri2.v[0] + tri2.v[1] + tri2.v[2]) / 3;

                tris.append(tri2);
            }
        }
    }

    assert(tris.length);
    BVHTree!Triangle bvh = New!(BVHTree!Triangle)(tris, 4);
    tris.free();
    return bvh;
}