module dlib.image.resampling.bilinear;

private
{
    import std.math;
    import dlib.image.image;
    import dlib.image.color;
}

SuperImage resampleBilinear(SuperImage img, in uint newWidth, in uint newHeight)
in
{
    assert (img.data.length);
}
body
{
    SuperImage res = img.createSameFormat(newWidth, newHeight);

    float xFactor = cast(float)img.width  / cast(float)newWidth;
    float yFactor = cast(float)img.height / cast(float)newHeight;

    int floor_x, floor_y, ceil_x, ceil_y;
    float fraction_x, fraction_y, one_minus_x, one_minus_y;

    ColorRGBAf c1, c2, c3, c4;
    ColorRGBAf col;
    float b1, b2;

    foreach(y; 0..res.height)
    foreach(x; 0..res.width)
    {
        floor_x = cast(int)floor(x * xFactor);
        floor_y = cast(int)floor(y * yFactor);

        ceil_x = floor_x + 1;
        if (ceil_x >= img.width) 
            ceil_x = floor_x;

        ceil_y = floor_y + 1;
        if (ceil_y >= img.height)
            ceil_y = floor_y;

        fraction_x = x * xFactor - floor_x;
        fraction_y = y * yFactor - floor_y;
        one_minus_x = 1.0f - fraction_x;
        one_minus_y = 1.0f - fraction_y;

        c1 = ColorRGBAf(img[floor_x, floor_y]);
        c2 = ColorRGBAf(img[ceil_x,  floor_y]);
        c3 = ColorRGBAf(img[floor_x, ceil_y]);
        c4 = ColorRGBAf(img[ceil_x,  ceil_y]);

        // Red
        b1 = one_minus_x * c1.r + fraction_x * c2.r;
        b2 = one_minus_x * c3.r + fraction_x * c4.r;
        col.r = one_minus_y * b1 + fraction_y * b2;

        // Green
        b1 = one_minus_x * c1.g + fraction_x * c2.g;
        b2 = one_minus_x * c3.g + fraction_x * c4.g;
        col.g = one_minus_y * b1 + fraction_y * b2;

        // Blue
        b1 = one_minus_x * c1.b + fraction_x * c2.b;
        b2 = one_minus_x * c3.b + fraction_x * c4.b;
        col.b = one_minus_y * b1 + fraction_y * b2;

        // Alpha
        b1 = one_minus_x * c1.a + fraction_x * c2.a;
        b2 = one_minus_x * c3.a + fraction_x * c4.a;
        col.a = one_minus_y * b1 + fraction_y * b2;

        res[x, y] = col.convert(res.bitDepth);
    }

    return res;
}

