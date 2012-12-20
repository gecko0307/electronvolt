module photon.core.application;

private
{
    import std.stdio;
    import std.conv;
    import std.string;
    import std.process;

    import derelict.util.compat;
    import derelict.sdl.sdl;
    import derelict.opengl.gl;
    import derelict.opengl.glu;
    import derelict.opengl.glext;
    import derelict.freetype.ft;
}

public
{ 
    import photon.core.appmanager;
}

class Application
{
    private:

    int _priv_quitActionId, _priv_resizeActionId;

    protected:

    uint videoWidth, videoHeight;
    AppManager manager;

    version(Windows)
    {
        enum sharedLibSDL = "SDL.dll";
        enum sharedLibFT = "freetype.dll";
    }
    version(linux)
    {
        enum sharedLibSDL = "./libsdl.so";
        enum sharedLibFT = "./libfreetype.so";
    }

    public:

    this(uint w, uint h, string caption, GLVersion glver = GLVersion.GL12)
    {
        videoWidth = w;
        videoHeight = h;

        DerelictGL.load();
        DerelictGLU.load();
        DerelictSDL.load(sharedLibSDL);
        DerelictFT.load(sharedLibFT);

        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) < 0)
            throw new Exception("Failed to init SDL: " ~ to!string(SDL_GetError()));

        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
        SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
        SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 5);
        SDL_GL_SetAttribute(SDL_GL_BUFFER_SIZE, 32);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);

        environment["SDL_VIDEO_WINDOW_POS"] = "";
        environment["SDL_VIDEO_CENTERED"] = "1";

        auto screen = SDL_SetVideoMode(videoWidth, videoHeight, 0, SDL_OPENGL | SDL_RESIZABLE);
        if (screen is null)
            throw new Exception("Failed to set video mode: " ~ to!string(SDL_GetError()));

        SDL_WM_SetCaption(toStringz(caption), null);
        SDL_ShowCursor(0);

        DerelictGL.loadClassicVersions(glver); 
        DerelictGL.loadExtensions();

        glViewport(0, 0, videoWidth, videoHeight);
        float aspectRatio = cast(float)videoWidth / cast(float)videoHeight;
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluPerspective(60, aspectRatio, 0.1, 200.0);
        glMatrixMode(GL_MODELVIEW);

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glEnable(GL_BLEND);
        glEnable(GL_NORMALIZE);
        glShadeModel(GL_SMOOTH);
        glAlphaFunc(GL_GREATER, 0.0);
        glEnable(GL_ALPHA_TEST);
        //glEnable(GL_TEXTURE);
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LESS);
        //glEnable(GL_LIGHTING);
        //glEnable(GL_LIGHT0);
        glEnable(GL_CULL_FACE);

        manager = new AppManager(videoWidth, videoHeight);

        int _priv_quitActionId = manager.bindActionToEvent(EventType.Quit, &onQuit);
        int _priv_resizeActionId = manager.bindActionToEvent(EventType.Resize, &onResize);
    }

    private:

    void onQuit()
    {
        manager.running = false;
    }

    void onResize()
    {
        SDL_Surface* screen = SDL_SetVideoMode(manager.event_width, 
                                               manager.event_height, 
                                               0, SDL_OPENGL | SDL_RESIZABLE);
        if (screen is null)
            throw new Exception("failed to set video mode: " ~ to!string(SDL_GetError()));

        glViewport(0, 0, manager.window_width, manager.window_height);
        float aspectRatio = cast(float)manager.window_width / cast(float)manager.window_height;
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluPerspective(60, aspectRatio, 0.1, 400.0);
        glMatrixMode(GL_MODELVIEW);
        //textInfo.setPos(16, manager.window_height-32); 
    }

    protected:

    void onUpdate()
    {
    }

    public:

    void run()
    {
        while (manager.running)
        {
            manager.update();

            onUpdate();

            SDL_GL_SwapBuffers();
            SDL_Delay(1);
        }

        manager.unbindActionFromEvent(EventType.Resize, _priv_resizeActionId);
        manager.unbindActionFromEvent(EventType.Quit, _priv_quitActionId);
    
        manager.free();

        SDL_Quit();
    }
}

