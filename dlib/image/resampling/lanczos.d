module dlib.image.resampling.lanczos;

private
{
    import std.math;
    import dlib.image.image;
    import dlib.image.color;
}

T lanczos(T) (T x, int filterSize)
{
    if (x <= -filterSize || x >= filterSize)
        return 0.0; // Outside of the window
    if (x > -T.epsilon && x < T.epsilon)
        return 1.0; // Special case the discontinuity at the origin
    
    auto sinc = (T x) => sin(PI * x) / (PI * x);
    return sinc(x) * sinc(x / filterSize);
}

SuperImage resampleLanczos(SuperImage img, in uint newWidth, in uint newHeight)
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
            float kSum;

            foreach(kx; -3..4)
            {
                int ix = ox1 + kx;

                if (ix < 0) ix = 0;
                if (ix >= img.width) ix = img.width - 1;

                foreach(ky; -3..4)
                {
                    int iy = oy1 + ky;

                    if (iy < 0) iy = 0;
                    if (iy >= img.height) iy = img.height - 1;

                    auto col = ColorRGBAf(img[ix, iy]);

                    float k1 = lanczos((cast(float)ky - dy), 3);
                    float k2 = k1 * lanczos((cast(float)kx - dx), 3);

                    kSum += k2;

                    colSum += col * k2;
                }
            }

            if (kSum > 0.0f) 
                colSum /= kSum;

            //colSum.clamp(0.0f, 1.0f);
            res[x, y] = colSum.convert(res.bitDepth);
        }
    }

    return res;
}

