module photon.graphics.material;

private
{
    import derelict.opengl.gl;
    import derelict.opengl.glext;
	
    import dlib.image.color;
	
    import photon.core.modifier;
    import photon.graphics.texture;
    import photon.graphics.shader;
}

enum TextureCombinerMode: ushort
{
    Blend = 0,
    Modulate = 1,
    Add = 2,
    Subtract = 3,
    Dot3 = 4,
    Dot3Alpha = 5
}

class Material: Modifier
{
    ColorRGBAf ambientColor;
    ColorRGBAf diffuseColor;
    ColorRGBAf specularColor;
    ColorRGBAf emissionColor;
    float shininess;
    Shader shader;
    Texture[8] textures;
    ushort[8] texBlendMode = 0;
    bool shadeless = false;

    this()
    {
        ambientColor = ColorRGBAf(0.2f, 0.2f, 0.2f, 1.0f);
        diffuseColor = ColorRGBAf(0.8f, 0.8f, 0.8f, 1.0f);
        specularColor = ColorRGBAf(1.0f, 1.0f, 1.0f, 1.0f);
        emissionColor = ColorRGBAf(0.0f, 0.0f, 0.0f, 1.0f);
        shininess = 8.0f;
    }

    void bind(double delta)
    {
        if (shadeless)
        {            glDisable(GL_LIGHTING);
            glColor4fv(diffuseColor.arrayof.ptr);
        }
        else
        {    
            glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, ambientColor.arrayof.ptr);
            glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, diffuseColor.arrayof.ptr);
            glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, specularColor.arrayof.ptr);
            glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, emissionColor.arrayof.ptr);
            glMaterialfv(GL_FRONT_AND_BACK, GL_SHININESS, &shininess);
        }

        glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_COMBINE);

        // TODO:
        // Select BlendMode
        //    Case T_Normal
        //        glTexEnvf (GL_TEXTURE_ENV, GL_COMBINE_RGB,GL_REPLACE)
        //    Case T_Blend
        //        glTexEnvf(GL_TEXTURE_ENV,GL_COMBINE_RGB,GL_BLEND)
        //    Case T_modulated
        //        glTexEnvf(GL_TEXTURE_ENV,GL_COMBINE_RGB,GL_MODULATE)
        //    Case T_Add
        //        glTexEnvf (GL_TEXTURE_ENV, GL_COMBINE_RGB,GL_ADD) 
        //    Case T_Dot3
        //        glTexEnvf (GL_TEXTURE_ENV, GL_COMBINE_RGB,GL_DOT3_RGB)
        //    Case T_Dot3Alpha
        //        glTexEnvf (GL_TEXTURE_ENV, GL_COMBINE_RGB,GL_DOT3_RGBA)
        //    Case T_Subtract
        //        glTexEnvf(GL_TEXTURE_ENV,GL_COMBINE_RGB,GL_SUBTRACT)

        foreach(i, tex; textures)
        {
            if (tex !is null)
            {
                glActiveTextureARB(GL_TEXTURE0_ARB + i);
                if (texBlendMode[i] == TextureCombinerMode.Modulate)
                {
                    glTexEnvf(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_MODULATE);
                }
                else
                {
                    glTexEnvf(GL_TEXTURE_ENV, GL_COMBINE_RGB, GL_BLEND);
                }
                tex.bind(delta);
            }
        }

        if (shader)
            shader.bind(delta);
    }

    void unbind()
    {
        if (shader)
            shader.unbind();

        foreach(i, tex; textures)
        {
            if (tex !is null)
            {
                glActiveTextureARB(GL_TEXTURE0_ARB + i);
                tex.unbind();
            }
        }

        glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);

        glActiveTextureARB(GL_TEXTURE0_ARB);
		
        if (shadeless)
            glEnable(GL_LIGHTING);
    }

    void free()
    {
    }
}
