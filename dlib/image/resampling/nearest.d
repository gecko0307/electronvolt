module dlib.image.resampling.nearest;

private
{
    import dlib.image.image;
    import dlib.image.color;
}

SuperImage resampleNearestNeighbor(SuperImage img, in uint newWidth, in uint newHeight)
in
{
    assert (img.data.length);
}
body
{
    SuperImage res = img.createSameFormat(newWidth, newHeight);

    float scaleWidth  = cast(float)newWidth / cast(float)img.width;
    float scaleHeight = cast(float)newHeight / cast(float)img.height;

    uint nearest_x, nearest_y;

    foreach(y; 0..res.height)
    foreach(x; 0..res.width)
    {
        nearest_x = cast(uint)(x / scaleWidth);
        nearest_y = cast(uint)(y / scaleHeight);
        res[x, y] = img[nearest_x, nearest_y];
    }

    return res;
}
