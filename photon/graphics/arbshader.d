module photon.graphics.arbshader;

private
{
    import std.stdio;
    import std.string;
    import std.conv;
	
    import derelict.opengl.gl;
    import derelict.opengl.glext;
	
    import photon.graphics.shader;
}

final class ARBShader: Shader
{
    GLuint vertShader;
    GLuint fragShader;
    bool _supported;
    
    this(string vertexProgram, string fragmentProgram)
    {
        _supported = supported;

        if (_supported)
        {
            int err;
            
            // Vertex shader 
            glEnable(GL_VERTEX_PROGRAM_ARB);
            glGenProgramsARB(1, &vertShader);
            glBindProgramARB(GL_VERTEX_PROGRAM_ARB, vertShader);
            glProgramStringARB(GL_VERTEX_PROGRAM_ARB, 
                               GL_PROGRAM_FORMAT_ASCII_ARB, 
                               vertexProgram.length, 
                               toStringz(vertexProgram));
            glGetIntegerv(GL_PROGRAM_ERROR_POSITION_ARB, &err);
            if (err >= 0)
                writefln("Error in vertex shader:\n%s",
    		        to!string(glGetString(GL_PROGRAM_ERROR_STRING_ARB)));
                    
            // Fragment shader
            glEnable(GL_FRAGMENT_PROGRAM_ARB);
            glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, fragShader);
            glProgramStringARB(GL_FRAGMENT_PROGRAM_ARB, 
                               GL_PROGRAM_FORMAT_ASCII_ARB,
  			                   fragmentProgram.length, 
                               toStringz(fragmentProgram));
            glGetIntegerv(GL_PROGRAM_ERROR_POSITION_ARB, &err);
            if (err >= 0)
                writefln("Error in fragment shader:\n%s",
    		        to!string(glGetString(GL_PROGRAM_ERROR_STRING_ARB)));
        }
    }
    
    override @property bool supported()
    {
        return DerelictGL.isExtensionSupported("GL_ARB_vertex_program") &&
               DerelictGL.isExtensionSupported("GL_ARB_fragment_program");
    }
    
    override void bind(double delta)
    {
        if (_supported)
        {
            glEnable(GL_VERTEX_PROGRAM_ARB);
            glEnable(GL_FRAGMENT_PROGRAM_ARB);
            glBindProgramARB(GL_VERTEX_PROGRAM_ARB, vertShader);
            glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, fragShader);
        }
    }
    
    override void unbind()
    {
        if (_supported)
        {
            glBindProgramARB(GL_VERTEX_PROGRAM_ARB, 0);
            glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, 0);
            glDisable(GL_VERTEX_PROGRAM_ARB);
            glDisable(GL_FRAGMENT_PROGRAM_ARB);
        }
    }
    
    override void free()
    {
    }
}

