module game.modelbvh;

import std.stdio;

import dlib.core.memory;
import dlib.container.array;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.geometry.triangle;

import dgl.asset.trimesh;
import dgl.asset.dgl3;

import dmech.bvh;

// TODO: This function is total hack,
// need to rewrite BVH module to handle Triangle ranges,
// and add a method to DGL3Resource that will lazily return 
// transformed triangles for entities.
BVHTree!Triangle modelBVH(DGL3Resource model)
{
    DynamicArray!Triangle tris;

    foreach(name, e; model.entitiesByName)
    {
        if (e.model)
        {
        /*
            // TODO
            if ("ghost" in e.props)
            {
                if (e.props["ghost"].toBool)
                    continue;
            }
        */
            Matrix4x4f mat = e.transformation;

            auto mesh = cast(Trimesh)e.model;

            if (mesh is null)
                continue;

            foreach(tri; mesh.triangles)
            {
                Triangle tri2;
                tri2.v[0] = mesh.vertices[tri[0]] * mat;
                tri2.v[1] = mesh.vertices[tri[1]] * mat;
                tri2.v[2] = mesh.vertices[tri[2]] * mat;
                tri2.normal = Vector3f(0, 0, 0);
                tri2.normal += mesh.normals[tri[0]];
                tri2.normal += mesh.normals[tri[1]];
                tri2.normal += mesh.normals[tri[2]];
                tri2.normal = (tri2.normal / 3.0);
                tri2.normal = e.rotation.rotate(tri2.normal);
                tri2.barycenter = (tri2.v[0] + tri2.v[1] + tri2.v[2]) / 3;
                tris.append(tri2);
            }
        }
    }

    //assert(tris.length);
    BVHTree!Triangle bvh = New!(BVHTree!Triangle)(tris, 100);
    tris.free();
    return bvh;
}
