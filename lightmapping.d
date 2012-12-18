module lightmapping;

private
{
    import std.math;
    import std.algorithm;
    import dlib.math.vector;
    import dlib.math.utils;
    import dlib.geometry.ray;
    import dlib.geometry.triangle;
    import dlib.image.image;
    import dlib.image.color;
    import photon.geometry.triangle;
    import photon.scene.bvh;
}

SuperImage genLightmap(Triangle[] tris, BVHTree!Triangle bvh)
{
    SuperImage lmap = new ImageRGBA8(512, 512);

    Vector3f lightPos = Vector3f(0.0f, 50.0f, 10.0f);

    foreach(tri; tris)
    {
        float min_u = min(tri.t1[0].x, tri.t1[1].x, tri.t1[2].x);
        float max_u = max(tri.t1[0].x, tri.t1[1].x, tri.t1[2].x);
        float min_v = min(tri.t1[0].y, tri.t1[1].y, tri.t1[2].y);
        float max_v = max(tri.t1[0].y, tri.t1[1].y, tri.t1[2].y);     

        uint min_x = cast(uint)(min_u * lmap.width - 0.5f);
        uint max_x = cast(uint)(max_u * lmap.width - 0.5f);
        uint min_y = cast(uint)(min_v * lmap.height - 0.5f);
        uint max_y = cast(uint)(max_v * lmap.height - 0.5f);

        foreach (x; min_x..max_x)
        foreach (y; min_y..max_y)
        {
            float u = (cast(float)x + 0.5f) / lmap.width;
            float v = (cast(float)y + 0.5f) / lmap.height;

            if (isPointInTriangle2D(Vector2f(u, v), tri.t1[0], tri.t1[1], tri.t1[2]))
            {
                Vector3f bcc = triBarycentricCoords(tri.t1[0], tri.t1[1], tri.t1[2], u, v);

                Vector3f P = triTextureSpaceToObjectSpace(tri.v[0], tri.v[1], tri.v[2], bcc);
                Vector3f N = triTextureSpaceToObjectSpace(tri.n[0], tri.n[1], tri.n[2], bcc);
                Vector3f L = (lightPos - P).normalized;

                float diffuse = clamp!float(dot(L, N), 0.0f, 1.0f);

                float shadow = 1.0f;

                Ray lightRay = Ray(P, lightPos);

                bvh.root.traverseRay(lightRay, (Triangle testTri)
                {
                    if (testTri != tri)
                    {
                        Vector3f rayIntersectionPoint;
                        bool inters;

                        inters = lightRay.intersectTriangle(testTri.v[0], testTri.v[1], testTri.v[2], rayIntersectionPoint);
                        if (inters)
                            shadow = 0.1f;
                    }
                });

                ColorRGBAf col = ColorRGBAf(0.2f, 0.1f, 0.0f) + ColorRGBAf(1.0f, 0.8f, 0.0f) * diffuse * shadow;
                col.a = 1.0f;

                lmap[x, y] = col.convert(lmap.bitDepth);
            }
        }
    }

    lmap = lmap.lmapFilter;

    return lmap;
}

struct PixelKernel 
{ 
    int x; 
    int y; 
}

SuperImage lmapFilter(SuperImage img)
in
{
    assert (img.data.length);
}
body
{
    SuperImage res = img.dup;

    static const PixelKernel neighbors[24] = 
    [ 
        {0,  1}, {0, -1}, {1, 0}, {-1, 0}, 
        {-1,-1}, {-1, 1}, {1, 1}, {1, -1},
        {0,  2}, {0, -2}, {2, 0}, {-2, 0}, 

        {-2, -1}, {-1, -2}, {1, -2}, {2, -1},
        {-2,  1}, {-1,  2}, {1,  2}, {2,  1},
        {-2, -2}, { 2, -2}, {-2, 2}, {2,  2},
    ]; 

    foreach(y; 0..img.height)
    foreach(x; 0..img.width)
    {
        ColorRGBAf resc = ColorRGBAf(img[x, y]);

        if (resc.a < 1.0f)
        {
            ColorRGBAf col = ColorRGBAf(0.0f, 0.0f, 0.0f, 0.0f);
            int count = 0; 
            for (int n = 0; n < 24; ++n) 
            { 
                int nx = x + neighbors[n].x; 
                int ny = y + neighbors[n].y;

                if (nx < 0 || ny < 0 || nx >= img.width || ny >= img.height)
                    continue;

                ColorRGBA neighborLumel = img[nx, ny];
 
                if (neighborLumel.a == 255)
                {		 
                    col += ColorRGBAf(neighborLumel); 
                    count++; 
                } 
            }

            if (count > 0) 
            {		 
                resc = col / cast(float)count;
                resc.a = 1.0f;
                res[x, y] = resc.convert(img.bitDepth);	 
            }
            else 
                res[x, y] = ColorRGBAf(0.2f, 0.1f, 0.0f, 1.0f).convert(img.bitDepth);	 
        } 
    }

    return res;
}

