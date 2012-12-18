module photon.ui.text;

private
{
    import derelict.opengl.gl;
    import derelict.opengl.glu;
    import derelict.freetype.ft;

    import photon.ui.font;
}

class Text 
{
    public:
    this(Font font)
    {
        m_font = font;
    }

    private:
    void pushScreenCoordinateMatrix()
    {
        glPushAttrib(GL_TRANSFORM_BIT);
        GLint viewport[4];
        glGetIntegerv(GL_VIEWPORT, viewport.ptr);
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        gluOrtho2D(viewport[0],viewport[2],viewport[1],viewport[3]);
        glPopAttrib();
    }

    void pop_projection_matrix()
    {
        glPushAttrib(GL_TRANSFORM_BIT);
        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glPopAttrib();
    }

    public:
    //Render text to window coordinates x,y, using the font.
    //The current modelview matrix will also be applied to the text.
    void render(T)(T str)
    {
        // We want a coordinate system where things coresponding to window pixels.
        pushScreenCoordinateMatrix();

        float h = m_font.getHeight() / 0.63f; //We make the height about 1.5* that of

        glPushAttrib(GL_LIST_BIT | GL_CURRENT_BIT  | GL_ENABLE_BIT | GL_TRANSFORM_BIT);    
        glMatrixMode(GL_MODELVIEW);
        glDisable(GL_LIGHTING);
        glEnable(GL_TEXTURE_2D);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        float modelview_matrix[16];    
        glGetFloatv(GL_MODELVIEW_MATRIX, modelview_matrix.ptr);

        //for (size_t i = 0; i < m_lines.length; ++i) {
        glPushMatrix();
        glLoadIdentity();
        glTranslatef(m_posX, m_posY - h * 0, 0);
        glMultMatrixf(modelview_matrix.ptr);

        // render a line of text
        //m_font.render(m_lines[i], m_sizes[i]);
        m_font.render(str);

        glPopMatrix();
        //}

        glPopAttrib();

        pop_projection_matrix();
    }

    void setPos(float x, float y) 
    {
        m_posX = x; 
        m_posY = y;
    }

    private:
    Font m_font;
    float m_posX, m_posY;
}

