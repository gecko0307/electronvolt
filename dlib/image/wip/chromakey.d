module dlib.image2.chromakey;

protected
{
    import dlib.image2.image2;
    import dlib.image2.rgb;
    import dlib.image2.hsv;
}

private
void selectiveScale(ref HSVAf col,
                    float hue,
                    HSVAChannel chan,
                    float scale,
                    bool inverse,
                    float hueToleranceMin = -20.0f, 
                    float hueToleranceMax = 20.0f, 
                    float satThres = 0.2f,
                    float valThres = 0.3f)
{
    while (hue >= 360.0f) 
        hue -= 360.0f;
    while (hue < 0.0f) 
        hue += 360.0f;

    if (col.hueInRange(hue, hueToleranceMin, hueToleranceMax) 
     && col.s > satThres && col.v > valThres)
    {
        if (!inverse) col.arrayof[chan] *= scale;
    }
    else
    {
        if (inverse) col.arrayof[chan] *= scale;
    }
}

public:

/*
 * Get alpha from color
 */
ImageRGBAb chromaKey(ImageRGBAb img,
               float hue,
               float hueToleranceMin = -20.0f, 
               float hueToleranceMax = 20.0f, 
               float satThres = 0.2f,
               float valThres = 0.3f,
               float* progress = null,
               bool* stop = null)
{
    ImageRGBAb res = ImageRGBAb(img);

    ubyte* imgptr = cast(ubyte*)img.data.ptr;
    ubyte* resptr = cast(ubyte*)res.data.ptr;

    float pixelPersentage = 1.0f / cast(float)(res.width * res.height);

    foreach(x; 0..img.width)
    foreach(y; 0..img.height)
    {
        auto col = img.getPixel(x, y).convertRGBAbToRGBAf.convertRGBAfToHSVAf;
        col.selectiveScale(hue, HSVAChannel.A, 0.0f, false, hueToleranceMin, hueToleranceMax, satThres, valThres);
        res.setPixel(x, y, col.convertHSVAfToRGBAf.convertRGBAfToRGBAb);

        if (progress !is null) 
           *progress += pixelPersentage;

        if (stop !is null)
            if (*stop) return img;
    }

    if (progress !is null) 
       *progress = 1.0f;

    return res;
}

/*
 * Turns image into b&w where only one color left
 */
ImageRGBAb colorPass(ImageRGBAb img,
               float hue,
               float hueToleranceMin = -20.0f, 
               float hueToleranceMax = 20.0f, 
               float satThres = 0.2f,
               float valThres = 0.3f,
               float* progress = null,
               bool* stop = null)
{
    ImageRGBAb res = ImageRGBAb(img);

    ubyte* imgptr = cast(ubyte*)img.data.ptr;

    float pixelPersentage = 1.0f / cast(float)(res.width * res.height);

    foreach(x; 0..img.width)
    foreach(y; 0..img.height)
    {
        auto col = img.getPixel(x, y).convertRGBAbToRGBAf.convertRGBAfToHSVAf;
        col.selectiveScale(hue, HSVAChannel.S, 0.0f, true, hueToleranceMin, hueToleranceMax, satThres, valThres);
        res.setPixel(x, y, col.convertHSVAfToRGBAf.convertRGBAfToRGBAb);

        if (progress !is null) 
           *progress += pixelPersentage;

        if (stop !is null)
            if (*stop) return img;
    }

    if (progress !is null) 
       *progress = 1.0f;

    return res;
}
              
