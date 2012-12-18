module photon.graphics.texture;

private
{
    import std.conv;

    import derelict.opengl.gl;
    import derelict.opengl.glu;
    import dlib.image.image;
    import photon.core.modifier;
}

class Texture: Modifier
{
    GLuint tex;
    GLenum format;
    GLenum type;
    int width;
    int height;

    this(SuperImage img, bool genMipmaps = true)
    {        
        createFromImage(img, genMipmaps);
    }
    
    void createFromImage(SuperImage img, bool genMipmaps = true)
    {
        free();

        width = img.width;
        height = img.height;
        
        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_2D, tex);

        if (genMipmaps)
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        }
        else 
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        }

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

        type = GL_UNSIGNED_BYTE;

        switch (img.pixelFormat)
        {
            case PixelFormat.L8:
                format = GL_LUMINANCE;
                break;
            case PixelFormat.LA8:
                format = GL_LUMINANCE_ALPHA;
                break;
            case PixelFormat.RGB8:
                format = GL_RGB;
                break;
            case PixelFormat.RGBA8:
                format = GL_RGBA;
                break;
            case PixelFormat.L16:
                format = GL_LUMINANCE;
                type = GL_UNSIGNED_SHORT;
                break;
            case PixelFormat.LA16:
                format = GL_LUMINANCE_ALPHA;
                type = GL_UNSIGNED_SHORT;
                break;
            case PixelFormat.RGB16:
                format = GL_RGB;
                type = GL_UNSIGNED_SHORT;
                break;
            case PixelFormat.RGBA16:
                format = GL_RGBA;
                type = GL_UNSIGNED_SHORT;
                break;
            default:
                assert (0, "Texture.createFromImage is not implemented for PixelFormat." 
                    ~ to!string(img.pixelFormat));
        }

        gluBuild2DMipmaps(GL_TEXTURE_2D, 
                          format, 
                          img.width, 
                          img.height, 
                          format, 
                          type, 
                          cast(void*)img.data.ptr);
    }

    void bind(double delta)
    {
        glEnable(GL_TEXTURE_2D);
        if (glIsTexture(tex)) 
            glBindTexture(GL_TEXTURE_2D, tex);
        else throw new Exception("Texture error");
    }	

    void unbind()
    {
        glBindTexture(GL_TEXTURE_2D, 0);
        glDisable(GL_TEXTURE_2D);
    }
	
    void free()
    {
        if (glIsTexture(tex)) 
            glDeleteTextures(1, &tex);
    }
}

