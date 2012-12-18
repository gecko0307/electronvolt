module photon.graphics.glslshader;

private
{
    import std.stdio;
    import std.string;
    import derelict.opengl.gl;
    import derelict.opengl.glext;
    import photon.graphics.shader;
}

final class GLSLShader: Shader
{
    GLenum shaderVert;
    GLenum shaderFrag;
    GLenum shaderProg;
    bool _supported;

    this(string vertexProgram, string fragmentProgram)
    {
        _supported = supported;

        if (_supported)
        {
            shaderProg = glCreateProgramObjectARB();
            shaderVert = glCreateShaderObjectARB(GL_VERTEX_SHADER_ARB);
            shaderFrag = glCreateShaderObjectARB(GL_FRAGMENT_SHADER_ARB);

            int len;
            char* srcptr;

            len = vertexProgram.length;
            srcptr = cast(char*)vertexProgram.ptr;
            glShaderSourceARB(shaderVert, 1, &srcptr, &len);

            len = fragmentProgram.length;
            srcptr = cast(char*)fragmentProgram.ptr;
            glShaderSourceARB(shaderFrag, 1, &srcptr, &len);

            glCompileShaderARB(shaderVert);
            glCompileShaderARB(shaderFrag);
            glAttachObjectARB(shaderProg, shaderVert);
            glAttachObjectARB(shaderProg, shaderFrag);
            glLinkProgramARB(shaderProg);

            char[1000] infobuffer = 0;
            int infobufferlen = 0;

            glGetInfoLogARB(shaderVert, 999, &infobufferlen, infobuffer.ptr);
            if (infobuffer[0] != 0)
                writefln("vp@shader.glsl.modifier: %s\n",infobuffer);

            glGetInfoLogARB(shaderFrag, 999, &infobufferlen, infobuffer.ptr);
            if (infobuffer[0] != 0)
                writefln("fp@shader.glsl.modifier:%s\n",infobuffer);
        }
    }

    override @property bool supported()
    {
        return DerelictGL.isExtensionSupported("GL_ARB_shading_language_100");
    }

    override void bind(double delta)
    {
        if (_supported)
        {
            glUseProgramObjectARB(shaderProg);
            glUniform1iARB(glGetUniformLocationARB(shaderProg, toStringz("gl_Texture0")), 0);
            glUniform1iARB(glGetUniformLocationARB(shaderProg, toStringz("gl_Texture1")), 1);
            glUniform1iARB(glGetUniformLocationARB(shaderProg, toStringz("gl_Texture2")), 2);
            glUniform1iARB(glGetUniformLocationARB(shaderProg, toStringz("gl_Texture3")), 3);
            glUniform1iARB(glGetUniformLocationARB(shaderProg, toStringz("gl_Texture4")), 4);
            glUniform1iARB(glGetUniformLocationARB(shaderProg, toStringz("gl_Texture5")), 5);
            glUniform1iARB(glGetUniformLocationARB(shaderProg, toStringz("gl_Texture6")), 6);
            glUniform1iARB(glGetUniformLocationARB(shaderProg, toStringz("gl_Texture7")), 7);
        }
    }

    override void unbind()
    {
        if (_supported)
        {
            glUseProgramObjectARB(0);
        }
    }

    override void free()
    {
    }
}
