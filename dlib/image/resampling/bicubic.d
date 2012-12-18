module dlib.image.resampling.bicubic;

private
{
    import std.math;
    import dlib.image.image;
    import dlib.image.color;
}

T bicubic(T) (T x)
{
    if (x > 2.0)
        return 0.0;
	
    T a, b, c, d;
    T xm1 = x - 1.0;
    T xp1 = x + 1.0;
    T xp2 = x + 2.0;

    a = ( xp2 <= 0.0 ) ? 0.0 : xp2 * xp2 * xp2;
    b = ( xp1 <= 0.0 ) ? 0.0 : xp1 * xp1 * xp1;
    c = ( x   <= 0.0 ) ? 0.0 : x * x * x;
    d = ( xm1 <= 0.0 ) ? 0.0 : xm1 * xm1 * xm1;

    return ( 0.16666666666666666667 * 
           ( a - ( 4.0 * b ) + ( 6.0 * c ) - ( 4.0 * d ) ) );
}

SuperImage resampleBicubic(SuperImage img, in uint newWidth, in uint newHeight)
in
{
    assert (img.data.length);
}
body
{
    SuperImage res = img.createSameFormat(newWidth, newHeight);

    float xFactor = cast(float)img.width  / cast(float)newWidth;
    float yFactor = cast(float)img.height / cast(float)newHeight;

    foreach(x; 0..res.width)
    {
        float ox = x * xFactor - 0.5f;
        int ox1 = cast(int)ox;
        float dx = ox - ox1;

        foreach(y; 0..res.height)
        {
            float oy = y * yFactor - 0.5f;
            int oy1 = cast(int)oy;
            float dy = oy - oy1;

            ColorRGBAf colSum;

            foreach(kx; -1..3)
            {
                int ix = ox1 + kx;

                if (ix < 0) ix = 0;
                if (ix >= img.width) ix = img.width - 1;

                foreach(ky; -1..3)
                {
                    int iy = oy1 + ky;

                    if (iy < 0) iy = 0;
                    if (iy >= img.height) iy = img.height - 1;

                    auto col = ColorRGBAf(img[ix, iy]);

                    float k1 = bicubic(dy - cast(float)ky);
                    float k2 = k1 * bicubic(cast(float)kx - dx);

                    colSum += col * k2;
                }
            }

            res[x, y] = colSum.convert(res.bitDepth);
        }
    }

    return res;
}

