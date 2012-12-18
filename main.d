module main;

private
{
    import std.stdio;
    import std.process;
    import std.string;
    import std.conv;
    import std.math;
    import std.random;
    import std.algorithm;
    import std.file;
    import std.array;
    import std.ascii;
    
    import derelict.util.compat;
    import derelict.sdl.sdl;
    import derelict.opengl.gl;
    import derelict.opengl.glu;
    import derelict.opengl.glext;
    import derelict.freetype.ft;
    import derelict.openal.al;
    import derelict.ogg.ogg;
    import derelict.ogg.vorbis;
    import derelict.ogg.vorbisenc;
    import derelict.ogg.vorbisfile;
    import derelict.ogg.theora;
    
    import dlib.core.stack;
    import dlib.math.vector;
    import dlib.math.matrix4x4;
    import dlib.math.utils;
    import dlib.geometry.ray;
    import dlib.geometry.triangle;
    import dlib.image.image;
    import dlib.image.color;
    import dlib.image.io.png;
    import dlib.image.filters.normalmap;
    import dlib.image.filters.morphology;
    
    import photon.all;

    import lightmapping;
    import dat;
}

Matrix4x4f getMVPMatrix()
{
    Matrix4x4f mvp;

    Matrix4x4f modelViewMatrix;
    glGetFloatv(GL_MODELVIEW_MATRIX, modelViewMatrix.arrayof.ptr);

    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
        glMultMatrixf(modelViewMatrix.arrayof.ptr);
    glGetFloatv(GL_PROJECTION_MATRIX, mvp.arrayof.ptr);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
 
    return mvp;
}

void drawTriMeshVA(TriMesh mesh)
{
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glEnableClientState(GL_NORMAL_ARRAY);
    if (mesh.tangents)
        glEnableClientState(GL_COLOR_ARRAY);

    glVertexPointer(3, GL_FLOAT, 0, mesh.vertices.ptr);
    glTexCoordPointer(2, GL_FLOAT, 0, mesh.texcoords.ptr);
    glNormalPointer(GL_FLOAT, 0, mesh.normals.ptr);
    if (mesh.tangents)
        glColorPointer(3, GL_FLOAT, 0, mesh.tangents.ptr);
    glDrawElements(GL_TRIANGLES, mesh.indices.length * 3, 
                   GL_UNSIGNED_INT, mesh.indices.ptr);
    if (mesh.tangents)
        glDisableClientState(GL_COLOR_ARRAY);
    glDisableClientState(GL_NORMAL_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);
}

Matrix4x4f directionToMatrix(Vector3f zdir)
{
    Vector3f xdir = Vector3f(0.0f, 0.0f, 1.0f);
    Vector3f ydir;
    float d = zdir.z;

    if (d > -0.999999999f && d < 0.999999999f)
    {
        xdir = xdir - zdir * d;
        xdir.normalize();
        ydir = cross(zdir, xdir);
    }
    else
    {
        xdir = Vector3f(zdir.z, 0.0f, -zdir.x);
        ydir = Vector3f(0.0f, 1.0f, 0.0f);
    }

    Matrix4x4f m = identityMatrix!float();
    m.forward = zdir;
    m.right = xdir;
    m.up = ydir;

    return m;
}

Vector3f vectorDecreaseToZero(Vector3f vector, float step)
{
    if (vector.x > 0.0f) vector.x -= step;
    if (vector.x < 0.0f) vector.x += step;
    if (vector.y > 0.0f) vector.y -= step;
    if (vector.y < 0.0f) vector.y += step;
    if (vector.z > 0.0f) vector.z -= step;
    if (vector.z < 0.0f) vector.z += step;
    return vector;
}

class DatRenderer
{
    uint[int] lists;
    DatObject obj;

    this(DatObject obj)
    {
        this.obj = obj;
        foreach(matIndex, mat; obj.materialByIndex)
        {
            uint list = glGenLists(1);
            glNewList(list, GL_COMPILE);
            //mat.bind(0.0);
            glBegin(GL_TRIANGLES);
            foreach(tri; obj.tris)
            {
                if (tri.materialIndex == matIndex)
                {                
                    glNormal3fv(tri.normal.arrayof.ptr);
                    //glNormal3fv(tri.n[0].arrayof.ptr);
                    glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[0].arrayof.ptr);
                    glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[0].arrayof.ptr);
                    glVertex3fv(tri.v[0].arrayof.ptr);
            
                    //glNormal3fv(tri.n[1].arrayof.ptr);
                    glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[1].arrayof.ptr);
                    glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[1].arrayof.ptr);
                    glVertex3fv(tri.v[1].arrayof.ptr);
            
                    //glNormal3fv(tri.n[2].arrayof.ptr);
                    glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[2].arrayof.ptr);
                    glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[2].arrayof.ptr);
                    glVertex3fv(tri.v[2].arrayof.ptr);
                }
            }
            glEnd();
            //mat.unbind();
            glEndList();
            lists[matIndex] = list;
        }
    }
    
    void render()
    {
        foreach(matIndex, mat; obj.materialByIndex)
        {
            uint list = lists[matIndex];
            mat.bind(0.0);
            glCallList(list);
            mat.unbind();
        }
    }
}

void main()
{
    uint windowWidth = 800;
    uint windowHeight = 600;
    bool windowCentered = true;
    bool soundEnabled = false;
    string linuxSDL = "./libsdl.so";
    string linuxFreeType = "./libfreetype.so";
    
    DerelictGL.load();
    DerelictGLU.load();
    version(Windows) DerelictSDL.load();
    version(linux) DerelictSDL.load(linuxSDL);
    version(Windows) DerelictFT.load();
    version(linux) DerelictFT.load(linuxFreeType);
    //DerelictFT.load();
    //DerelictAL.load();
    //DerelictOgg.load();
    //DerelictVorbis.load();
    //DerelictVorbisFile.load();
    //DerelictTheora.load();

    //writeln(to!string(theora_version_string()));
    
    if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) < 0)
        throw new Exception("Failed to init SDL: " ~ toDString(SDL_GetError()));
        
    scope(exit) 
    {
        if (SDL_Quit !is null) SDL_Quit();
    }
    
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
    SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 5);
    SDL_GL_SetAttribute(SDL_GL_BUFFER_SIZE, 32);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
    
    if (windowCentered)
    {
        environment["SDL_VIDEO_WINDOW_POS"] = "";
        environment["SDL_VIDEO_CENTERED"] = "1";
    }
    
    auto screen = SDL_SetVideoMode(windowWidth, windowHeight, 0, SDL_OPENGL | SDL_RESIZABLE);
    if (screen is null)
        throw new Exception("failed to set video mode: " ~ toDString(SDL_GetError()));

    SDL_WM_SetCaption(toStringz("Atrium"), null);
    SDL_ShowCursor(0);

    DerelictGL.loadClassicVersions(GLVersion.GL12); 
    DerelictGL.loadExtensions();
    
    glClearColor(0.0f, 0.5f, 1.0f, 1.0f);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
    glEnable(GL_NORMALIZE);
    glShadeModel(GL_SMOOTH);
    glAlphaFunc(GL_GREATER, 0.0);
    glEnable(GL_ALPHA_TEST);
    glEnable(GL_TEXTURE);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glEnable(GL_CULL_FACE);
    
    glViewport(0, 0, windowWidth, windowHeight);
    float aspectRatio = cast(float)windowWidth / cast(float)windowHeight;
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluPerspective(60, aspectRatio, 0.1, 200.0);
    glMatrixMode(GL_MODELVIEW);
    
    Vector4f lightPos = Vector4f(0.0f, 40.0f, 0.0f, 1.0f);
    glLightfv (GL_LIGHT0, GL_POSITION, lightPos.arrayof.ptr);
    
    float density = 1.0f;
    float[4] fogColor = [0.5f, 0.5f, 0.5f, 1.0f];
    
    glFogi(GL_FOG_MODE, GL_EXP);
    glFogfv(GL_FOG_COLOR, fogColor.ptr);
    glFogf(GL_FOG_DENSITY, 0.01f);
    glHint(GL_FOG_HINT, GL_DONT_CARE);
    glFogf(GL_FOG_START, 180.0f);
    glFogf(GL_FOG_END, 200.0f);
    //glEnable(GL_FOG);
    
    AppManager app = new AppManager(windowWidth, windowHeight);
    
    // Create font and text
    Font ftDroidSans = new Font();
    ftDroidSans.init("data/fonts/droid/DroidSans.ttf", 14);

    Text textInfo = new Text(ftDroidSans);
    textInfo.setPos(16, windowHeight-32);

    Text textFPS = new Text(ftDroidSans);
    textFPS.setPos(16, 16);
    
    // Create objects
    Empty scene = new Empty();

    // Create cameras
    TrackballCamera camera = new TrackballCamera();
    camera.pitch(45);
    int tempMouseX = 0;
    int tempMouseY = 0;

    Empty camera3rdPerson = new Empty(scene);
    camera3rdPerson.bsphereRadius = 1.0f;
    Sphere camSphere = new Sphere(camera3rdPerson.bsphereRadius, 12, 6, camera3rdPerson);
    camSphere.visible = false; 

    bool freeCamera = false;

    //score += collectibleCost[c.type];
    ulong score = 0;
    uint[uint] collectibleCost = 
    [
        0: 1,
        1: 10,
        2: 25,
        3: 100,
        4: 500
    ];

    float cPhereRotZ = 0.0f;
   
    // Create character
    MD5AnimatedMesh amesh = MD5AnimatedMesh("data/character/character.md5mesh");
    MD5Animation anim_idle = MD5Animation("data/character/character-idle.md5anim");
    MD5Animation anim_walk = MD5Animation("data/character/character-walk.md5anim");
    MD5Animation anim_jump = MD5Animation("data/character/character-jump.md5anim");
    MD5Animation anim_fall = MD5Animation("data/character/character-fall.md5anim");

    Empty lionPivot = new Empty(scene);
    lionPivot.bsphereRadius = 3.0f;
    lionPivot.position = Vector3f(0.0f, 20.0f, 10.0f);
    MD5Actor lion = new MD5Actor(amesh, lionPivot);
    lion.setAnimation(&anim_idle);
    //lion.modifiers ~= tex;
    //lion.modifiers ~= m3;
    lion.roll(180.0f);
    lion.pitch(-90.0f);
    lion.position.y -= lionPivot.bsphereRadius;
    Sphere lionSphere = new Sphere(lionPivot.bsphereRadius, 12, 6, lionPivot);
    lionSphere.visible = false;

    MD5ArraysAlloc();
    
    enum 
    {
        ST_IDLE,
        ST_WALK,
        ST_JUMP,
        ST_FALL
    }
    
    uint animState = ST_IDLE;
/*
    // Doesn't work with LDC
    MD5Animation*[uint] animations = 
    [
        ST_IDLE: &anim_idle,
        ST_WALK: &anim_walk,//&anim_walk,
        ST_JUMP: &anim_jump,
        ST_FALL: &anim_fall
    ];
*/

    MD5Animation*[uint] animations;
    animations[ST_IDLE] = &anim_idle;
    animations[ST_WALK] = &anim_walk;
    animations[ST_JUMP] = &anim_jump;
    animations[ST_FALL] = &anim_fall;

    void setAnimationState(uint st, float sm = 1.0f)
    {
        if (st != animState)
        {
            lion.smoothSwitchToAnimation(animations[st], sm);
            animState = st;
        }
    }
    
    SceneNode player = lionPivot;

    float jump = 0.0f;
    float grav = 0.0f;

    const float gravity = 50.0f; //0.001f;
    const float jumpcoef = 40.0f; //0.15f;

    Vector3f pushVector = Vector3f(0.0f, 0.0f, 0.0f);

    auto shadowImg = loadPNG("data/fx/shadow.png");
    Texture shadowTex = new Texture(shadowImg);
    //ColorRGBAf shadowColor = ColorRGBAf(0.0f, 0.0f, 0.0f, 1.0f);
    float shadowAlpha = 1.0f;

    auto glowImg = loadPNG("data/fx/glow.png");
    Texture glowTex = new Texture(glowImg);

    DatObject level = new DatObject("data/arena/arena.dat");

    //writeln(level.spawnPosition);
    lionPivot.position = level.spawnPosition;
    //writeln(level.spawnRotation);
    lionPivot.rotation = level.spawnRotation;
    
    DatRenderer dr = new DatRenderer(level);

    // Create BVH
    BVHTree!Triangle bvh = new BVHTree!Triangle(level.tris, 8, Heuristic.SAH);/*
    bvh.root.traverse((BVHNode!Triangle node)
    {
        node.userData = glGenLists(1);
        glNewList(node.userData, GL_COMPILE);
        foreach(tri; node.objects)
        {       
            Material* mat = tri.materialIndex in level.materialByIndex;
                
            if (mat !is null)
                mat.bind(0.0);
                
            glBegin(GL_TRIANGLES);
            glNormal3fv(tri.normal.arrayof.ptr);
            //glNormal3fv(tri.n[0].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[0].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[0].arrayof.ptr);
            glVertex3fv(tri.v[0].arrayof.ptr);
            
            //glNormal3fv(tri.n[1].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[1].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[1].arrayof.ptr);
            glVertex3fv(tri.v[1].arrayof.ptr);
            
            //glNormal3fv(tri.n[2].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE0_ARB, tri.t1[2].arrayof.ptr);
            glMultiTexCoord2fvARB(GL_TEXTURE1_ARB, tri.t2[2].arrayof.ptr);
            glVertex3fv(tri.v[2].arrayof.ptr);
            glEnd();
            
            if (mat !is null)
                mat.unbind();
        }
        glEndList();
    });
*/
    DatObject collectibleSphere = new DatObject("data/items/gem.dat");
    DatRenderer cSphere = new DatRenderer(collectibleSphere);
    collectibleSphere.materials[0].ambientColor = collectibleSphere.materials[0].diffuseColor;
    collectibleSphere.materials[0].diffuseColor.a = 0.9f;
    //new Sphere(1.0f, 12, 6, null);
    Material mCollectibleSphere = new Material();
    Billboard cSphereBBoard = new Billboard(5.0f, 5.0f, null);
    
    // Create materials and shaders
    auto characterImg = loadPNG("data/character/character-texture.png");
    Texture characterTex = new Texture(characterImg);
    
    Material mLion = new Material();
    mLion.ambientColor = ColorRGBAf(0.9f, 0.9f, 0.9f, 1.0f);
    mLion.diffuseColor = ColorRGBAf(0.9f, 0.9f, 0.9f, 1.0f);
    mLion.specularColor = ColorRGBAf(1.0f, 1.0f, 1.0f, 1.0f);
    //mLion.shininess = 32.0f;
    mLion.textures[0] = characterTex;
    //auto mLionShader = new GLSLShader(
    //    readText("atrium/shaders/phong.vp.glsl"), 
    //    readText("atrium/shaders/phong.fp.glsl"));
    //mLion.shader = mLionShader;

    ParticleEmitter pEmitter = new ParticleEmitter();

/*
    auto mechTmapImg = loadPNG("data/models/cube/tangentmap.png");
    Texture mechTexTangent = new Texture(mechTmapImg);

    auto mech2Img = loadPNG("data/models/cube/rockwall.png");
    Texture mechTexDiffuse = new Texture(mech2Img);

    auto mech3Img = loadPNG("data/models/cube/rockwall-height.png");
    Texture mechTexHeight = new Texture(mech3Img);

    auto mechImg = heightToNormal(mech3Img);
    Texture mechTexNormal = new Texture(mechImg);

    auto parallaxMapping = new GLSLShader(
        readText("data/shaders/parallax.vp.glsl"), 
        readText("data/shaders/parallax.fp.glsl"));
    Material mHK = new Material();
    mHK.ambientColor = ColorRGBAf(0.5f, 0.5f, 0.5f, 1.0f);
    mHK.diffuseColor = ColorRGBAf(0.9f, 0.9f, 0.9f, 1.0f);
    mHK.specularColor = ColorRGBAf(1.0f, 1.0f, 1.0f, 1.0f);
    mHK.shininess = 8.0f;
    mHK.textures[0] = mechTexDiffuse;
    if (parallaxMapping.supported)
    {
        mHK.textures[1] = mechTexNormal;
        mHK.textures[2] = mechTexHeight;
        mHK.textures[3] = mechTexTangent;
        mHK.shader = parallaxMapping;
    }
*/
/*
    void drawCulled(BVHNode!Triangle node, Frustum frst)
    {
        if (frst.containsAABB(node.aabb) || 
            frst.intersectsAABB(node.aabb))
        {
            if (node.child[0] !is null)
                drawCulled(node.child[0], frst);
            if (node.child[1] !is null)
                drawCulled(node.child[1], frst);

            if (node.userData)
            {
                glCallList(node.userData);
            }
        }
    }
    
    void drawEverything(BVHNode!Triangle node)
    {
        if (node.child[0] !is null)
            drawEverything(node.child[0]);
        if (node.child[1] !is null)
            drawEverything(node.child[1]);

        if (node.userData > 0) 
            glCallList(node.userData);
    }
*/
    bool frustumCulling = true;
    Frustum frst;

    int quitActionId = app.bindActionToEvent(EventType.Quit, ()
    {
        app.running = false;
    });

    int resizeActionId = app.bindActionToEvent(EventType.Resize, ()
    {
        SDL_Surface* screen = SDL_SetVideoMode(app.event_width, 
                                               app.event_height, 
                                               0, SDL_OPENGL | SDL_RESIZABLE);
        if (screen is null)
            throw new Exception("failed to set video mode: " ~ toDString(SDL_GetError()));

        glViewport(0, 0, app.window_width, app.window_height);
        float aspectRatio = cast(float)app.window_width / cast(float)app.window_height;
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluPerspective(60, aspectRatio, 0.1, 400.0);
        glMatrixMode(GL_MODELVIEW);

        textInfo.setPos(16, app.window_height-32); 
    });
    
    int keyDownActionId = app.bindActionToEvent(EventType.KeyDown, ()
    {
        if (app.event_key == SDLK_ESCAPE)
        {
            app.running = false;
        }
        else if (app.event_key == SDLK_F10)
        {
            frustumCulling = !frustumCulling;
        }
        else if (app.event_key == SDLK_F11)
        {
            freeCamera = !freeCamera;
        }
    });

    int keyUpActionId = app.bindActionToEvent(EventType.KeyUp, ()
    {
    });

    int mouseButtonDownActionId = app.bindActionToEvent(EventType.MouseButtonDown, ()
    {
        if ( app.event_button == SDL_BUTTON_RIGHT ) 
        {
            tempMouseX = app.mouse_x;
            tempMouseY = app.mouse_y;
            SDL_WarpMouse(cast(ushort)app.window_width/2, cast(ushort)app.window_height/2);
        }
        else if ( app.event_button == SDL_BUTTON_LEFT ) 
        {
        }
        else if ( app.event_button == SDL_BUTTON_MIDDLE ) 
        {
            tempMouseX = app.mouse_x;
            tempMouseY = app.mouse_y;
            SDL_WarpMouse(cast(ushort)app.window_width/2, cast(ushort)app.window_height/2);
        }
        else if ( app.event_button == SDL_BUTTON_WHEELUP ) 
        {
            camera.zoomSmooth(-2.0f,16.0f);
        }
        else if ( app.event_button == SDL_BUTTON_WHEELDOWN ) 
        {
            camera.zoomSmooth(2.0f,16.0f);
        }
    });
    
    dstring infoString = "0";

    string walkSound = "";
    float life = 1.0f;

    while (app.running)
    {
        //app.reset();
        app.update();

        // Camera control
        if (app.rmb_pressed)
        {
            float turn_m = (cast(float)(app.window_width/2 - app.mouse_x))/8.0f;
            float pitch_m = -(cast(float)(app.window_height/2 - app.mouse_y))/8.0f;
            camera.pitchSmooth(pitch_m, 16.0f);
            camera.turnSmooth(turn_m, 16.0f);
            SDL_WarpMouse(cast(ushort)app.window_width/2, cast(ushort)app.window_height/2);
        }

        if (app.mmb_pressed || (app.lmb_pressed && app.key_pressed[SDLK_LSHIFT]))
        {
            float shift_x = (cast(float)(app.window_width/2 - app.mouse_x))/16.0f;
            float shift_y = (cast(float)(app.window_height/2 - app.mouse_y))/16.0f;
            camera.moveSmooth(shift_y, 16.0f);
            camera.strafeSmooth(-shift_x, 16.0f);
            SDL_WarpMouse(cast(ushort)app.window_width/2, cast(ushort)app.window_height/2);
        }
        
        double delta = min(0.05f, app.deltaTime);
        float speed = 17.0f * delta;

        float floorHeight = 0.0f;
        float ceilHeight = float.max;

        Vector3f groundPoint = Vector3f(0.0f, 0.0f, 0.0f);
        Vector3f groundNormal = Vector3f(0.0f, 1.0f, 0.0f);
    
        Ray downRay;
        downRay.p0 = player.position;
        downRay.p1 = Vector3f(player.position.x, 0.0f, player.position.z);

        Ray upRay;
        upRay.p0 = player.position;
        upRay.p1 = player.position + Vector3f(0.0f, 25.0f, 0.0f);

        bvh.root.traverseRay(downRay, (Triangle tri)
        {
            Vector3f rayIntersectionPoint;
            bool inters;

            inters = downRay.intersectTriangle(tri.v[0], tri.v[1], tri.v[2], rayIntersectionPoint);
            if (inters)
            {
                float dist = distance(player.position, rayIntersectionPoint);

                if (rayIntersectionPoint.y > floorHeight)
                {
                    floorHeight = rayIntersectionPoint.y;
                    groundNormal = tri.normal;

                    auto matMeta = level.materialMetaByIndex[tri.materialIndex];

                    if (walkSound != matMeta.touchSound)
                    {
                        writeln(matMeta.touchSound);
                        walkSound = matMeta.touchSound;
                    }

                    // Let the lightmap to affect character
                    auto m = level.materialByIndex[tri.materialIndex];
                    if (m.textures[1] !is null)
                    {
                        Vector2f tc = triObjectSpaceToTextureSpace(
                            tri.v[0], tri.v[1], tri.v[2],
                            tri.t2[0], tri.t2[1], tri.t2[2],
                            rayIntersectionPoint);

                        auto lmap = level.images[m.textures[1].tex];
                        uint tex_x = cast(uint)(tc.x * lmap.width - 0.5f);
                        uint tex_y = cast(uint)(tc.y * lmap.height - 0.5f);
                        auto groundLumel = ColorRGBAf(lmap[tex_x, tex_y]);
                        groundLumel.a = 1.0f;
                        mLion.ambientColor = groundLumel;
                        mLion.diffuseColor = groundLumel;
                        mLion.specularColor = groundLumel;
                        shadowAlpha = 0.25f + groundLumel.luminance;
                    }
                }
            }
        });

        bvh.root.traverseRay(upRay, (Triangle tri)
        {
            Vector3f rayIntersectionPoint;
            bool inters;

            inters = upRay.intersectTriangle(tri.v[0], tri.v[1], tri.v[2], rayIntersectionPoint);
            if (inters)
            {
                if (rayIntersectionPoint.y < ceilHeight)
                    ceilHeight = rayIntersectionPoint.y;
            }
        });

        if (player.position.y - player.boundingSphere.radius > floorHeight)
        {
            grav += gravity * delta;
        }
        else
        {
            jump = 0.0f;
            grav = 0.0f;
            player.position.y = floorHeight + player.boundingSphere.radius;
        }

        if (jump > 0.0f) 
            jump -= gravity * delta;

        if (player.position.y + player.boundingSphere.radius >= ceilHeight)
        {
            jump = 0.0f;
        }

        if (app.key_pressed[SDLK_UP])
            player.move(speed);
        if (app.key_pressed[SDLK_DOWN])
            player.move(-speed);
        if (app.key_pressed[SDLK_LEFT])
            player.turn(220.0f * delta);
        if (app.key_pressed[SDLK_RIGHT])
            player.turn(-220.0f * delta);
        if (app.key_pressed[SDLK_SPACE])
        {
            if ((player.position.y - player.boundingSphere.radius) <= floorHeight+0.1f)
            {
                jump = jumpcoef;
            }
        }

        pushVector = vectorDecreaseToZero(pushVector, 30.0f * delta);

        player.lift((jump - grav) * delta);
        player.translate(pushVector * delta);

        bool lastCollided = false;

        bvh.root.traverse(player, (Triangle tri)
        {
            IntersectionTestResult intersection;
            testSphereVsTriangle(
                player.boundingSphere.position, 
                player.boundingSphere.radius, 
                intersection, 
                tri);

            if (intersection.valid)
            {
                lastCollided = true;

                auto matMeta = level.materialMetaByIndex[tri.materialIndex];

                float surfaceDivergenceCos = dot(Vector3f(0.0f, 1.0f, 0.0f), tri.normal);

                if (surfaceDivergenceCos < 0.5f)
                {
                    player.position += intersection.contactNormal * intersection.penetrationDepth;

                    if (matMeta.danger > 0)
                    {
                        life -= matMeta.danger;
                        pushVector = player.velocity.normalized * -40.0f;
                    }
                }
                else
                {
                    if (matMeta.danger > 0)
                    {
                        life -= matMeta.danger;
                        pushVector = intersection.contactNormal * 40.0f;
                    }
                }
            }
        });

        // Handle collectibles and enemies
        foreach(c; level.collectibles)
        {
            if (!c.available) continue;
            BSphere collSphere = BSphere(c.position, 1.0f);
            Vector3f contactNormal;
            float penetrationDepth;
            if (player.boundingSphere.intersectsSphere(collSphere, contactNormal, penetrationDepth))
            {
                c.available = false;
                score += collectibleCost[c.type];
            }
        }

        // Move camera
        Vector3f cameraTargetPosition = player.position + (-player.localMatrix.forward * 12.0f);
        cameraTargetPosition.y += 3.0f;
        if (camera3rdPerson.position != cameraTargetPosition)
        {
            Vector3f translateVec = ((cameraTargetPosition - camera3rdPerson.position)*5.0f) * delta;
            if (translateVec.length > camera3rdPerson.boundingSphere.radius)
                translateVec = translateVec.normalized * camera3rdPerson.boundingSphere.radius;
            camera3rdPerson.translate(translateVec);
        }

        float camDist = distance(player.position, camera3rdPerson.position);

        bvh.root.traverse(camera3rdPerson, (Triangle tri)
        {
            IntersectionTestResult intersection;
            testSphereVsTriangle(
                camera3rdPerson.boundingSphere.position, 
                camera3rdPerson.boundingSphere.radius, 
                intersection, 
                tri);

            if (intersection.valid)
            {
                if (camDist < 15.0f)
                    camera3rdPerson.position += intersection.contactNormal * intersection.penetrationDepth; 
            }
        });
        
        // Update animation
        //if (player.position.y - player.boundingSphere.radius < floorHeight-0.5f)
        //{
        //    setAnimationState(ST_FALL, 0.1f);
        //}
        if (player.position.y-player.boundingSphere.radius > floorHeight+0.5f)
        {
            //if (!lastCollided)
            setAnimationState(ST_FALL, 0.1f);
        }
        else
        {
            if (app.key_pressed[SDLK_UP])
                setAnimationState(ST_WALK);
            else if (app.key_pressed[SDLK_DOWN])
                setAnimationState(ST_WALK);
            //else if (tpc.jaxisY > 0.1)
            //    setAnimationState(ST_WALK, min(0.3f + abs(tpc.jaxisY), 1.0f));
            //else if (tpc.jaxisY < -0.1)
            //    setAnimationState(ST_WALK, min(0.3f + abs(tpc.jaxisY), 1.0f));
            else
                setAnimationState(ST_IDLE, 0.5f);
        }

        // Draw everything
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glLoadIdentity();

        // Bind camera
        if (freeCamera)
            camera.bind(app.deltaTime);
        else
        {
            glPushMatrix();
            Matrix4x4f cameraMatrix = 
                lookAtMatrix(
                    camera3rdPerson.position, 
                    player.position, 
                    Vector3f(0.0f, 1.0f, 0.0f));
            glLoadMatrixf(cameraMatrix.arrayof.ptr);
        }

        glLightfv(GL_LIGHT0, GL_POSITION, lightPos.arrayof.ptr);

        // Draw scene
        //frst.setFromMVP(getMVPMatrix());
        //drawCulled(bvh.root, frst);
        dr.render();

        // Draw shadow
        Matrix4x4f shadowRotMat = directionToMatrix(groundNormal);
        glPushMatrix();
        Vector3f translation = Vector3f(player.position.x, floorHeight, player.position.z);
        translation += groundNormal * 0.1f;
        glTranslatef(translation.x, translation.y, translation.z);
        glMultMatrixf(shadowRotMat.arrayof.ptr);
        float scaleFactor = 5.0f + (player.position.y - floorHeight) * 0.5f;
        glScalef(scaleFactor, scaleFactor, scaleFactor);
        shadowTex.bind(app.deltaTime);
        glDisable(GL_LIGHTING);
        glColor4f(1.0f, 1.0f, 1.0f, shadowAlpha);
        glBegin(GL_QUADS);
        glTexCoord2f(0.0f, 1.0f); glVertex3f(-0.5f, -0.5f, 0.0f);
        glTexCoord2f(1.0f, 1.0f); glVertex3f(0.5f, -0.5f, 0.0f);
        glTexCoord2f(1.0f, 0.0f); glVertex3f(0.5f, 0.5f, 0.0f);
        glTexCoord2f(0.0f, 0.0f); glVertex3f(-0.5f, 0.5f, 0.0f);
        glEnd();
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glEnable(GL_LIGHTING);
        shadowTex.unbind();
        glPopMatrix();
        
        mLion.bind(app.deltaTime);
        player.draw(app.deltaTime);
        mLion.unbind();

        //pEmitter.draw(app.deltaTime);

        foreach(c; level.collectibles)
        {
            if (!c.available) continue;
            glPushMatrix();
            glTranslatef(c.position.x, c.position.y, c.position.z);
            glRotatef(cPhereRotZ, 0.0f, 1.0f, 0.0f);
            glRotatef(30.0f, 1.0f, 0.0f, 0.0f);
            cSphere.render();
            glPopMatrix();
        }

        cPhereRotZ += 90.0f * app.deltaTime;

        glPushAttrib(GL_ENABLE_BIT); 
        glDisable(GL_LIGHTING);
        glDepthMask( GL_FALSE );
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        foreach(c; level.collectibles)
        {
            if (!c.available) continue;
            glowTex.bind(app.deltaTime);
            glColor4f(1.0f, 0.0f, 1.0f, 0.4f);
            Vector3f toCamera = (camera3rdPerson.position - c.position).normalized;
            cSphereBBoard.position = c.position + toCamera * 1.5f;
            cSphereBBoard.render(app.deltaTime);
            glowTex.unbind();
        }
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDepthMask( GL_TRUE );
        glPopAttrib();
        
        if (freeCamera)
            camera.unbind();
        else
            glPopMatrix();

        // 2D mode
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        glOrtho(0, app.window_width, 0, app.window_height, -1, 1);
        glMatrixMode(GL_MODELVIEW);

        glLoadIdentity();

        glDisable(GL_LIGHTING);

        //infoString = to!dstring(life);

        glColor3f(1.0f, 1.0f, 1.0f);
        static char buffer[20] = 0; 
        sprintf(buffer.ptr, "Score: %d", score); 
        textInfo.render(to!string(buffer));
        buffer[] = 0; 
        sprintf(buffer.ptr, "%d FPS", app.fps); 
        textFPS.render(to!string(buffer));

        glEnable(GL_LIGHTING);

        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);

        SDL_GL_SwapBuffers();
        SDL_Delay(1);
    }
    
    app.unbindActionFromEvent(EventType.MouseButtonDown, mouseButtonDownActionId);
    app.unbindActionFromEvent(EventType.KeyDown, keyDownActionId);
    app.unbindActionFromEvent(EventType.Resize, resizeActionId);
    app.unbindActionFromEvent(EventType.Quit, quitActionId);
    
    app.free();
}

