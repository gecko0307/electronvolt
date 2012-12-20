module gameapp;

private
{
    import std.stdio;
    import std.conv;
    import std.string;
    import std.process;
    import std.algorithm;

    import derelict.util.compat;
    import derelict.sdl.sdl;
    import derelict.opengl.gl;
    import derelict.opengl.glu;
    import derelict.opengl.glext;
    import derelict.freetype.ft;

    import dlib.math.vector;
    import dlib.math.matrix4x4;
    import dlib.math.utils;
    import dlib.geometry.ray;
    import dlib.geometry.triangle;
    import dlib.image.image;
    import dlib.image.color;
    import dlib.image.io.png;

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

class GameApp: Application
{
    Vector4f vec_lightPos;
    Font ft_main;
    Text txt_info;
    Text txt_fps;

    Empty scene;
    TrackballCamera camera;
    Empty camera3rdPerson;
    int tempMouseX = 0;
    int tempMouseY = 0;

    bool freeCamera = false;
    ulong score = 0;
    uint[uint] collectibleCost;
    float cPhereRotZ = 0.0f;

    MD5AnimatedMesh chAMesh;
    MD5Animation chAnimIdle;
    MD5Animation chAnimWalk;
    MD5Animation chAnimJump;
    MD5Animation chAnimFall;

    Empty chPivot;
    MD5Actor chActor;
    Sphere chColSphere;

    enum 
    {
        ST_IDLE,
        ST_WALK,
        ST_JUMP,
        ST_FALL
    }

    MD5Animation*[uint] chAnimations;
    uint chAnimState = ST_IDLE;

    SceneNode player;

    float playerJump = 0.0f;
    float playerGrav = 0.0f;

    const float gravity = 50.0f; //0.001f;

    const float playerJumpCoef = 40.0f; //0.15f;

    Vector3f pushVector;

    SuperImage chTextureImage;
    Texture chTexture;
    Material chMaterial;

    Texture shadTexture;
    Texture glowTexture;

    float shadAlpha = 1.0f;

    DatObject level;
    DatRenderer dr;
    BVHTree!Triangle bvh;

    DatObject do_gem;
    DatRenderer dr_gem;
    Billboard bb_gemGlow;
    float gemRotZ = 0.0f;

    bool frustumCulling = true;
    Frustum frst;

    string walkSound = "";
    float life = 1.0f;

    this(uint w, uint h, string caption)
    {
        super(w, h, caption);

        glClearColor(0.0f, 0.5f, 1.0f, 1.0f);

        glEnable(GL_LIGHTING);
        glEnable(GL_LIGHT0);
        vec_lightPos = Vector4f(0.0f, 40.0f, 0.0f, 1.0f);
        glLightfv (GL_LIGHT0, GL_POSITION, vec_lightPos.arrayof.ptr);
    
        float density = 1.0f;
        float[4] fogColor = [0.5f, 0.5f, 0.5f, 1.0f];
    
        glFogi(GL_FOG_MODE, GL_EXP);
        glFogfv(GL_FOG_COLOR, fogColor.ptr);
        glFogf(GL_FOG_DENSITY, 0.01f);
        glHint(GL_FOG_HINT, GL_DONT_CARE);
        glFogf(GL_FOG_START, 180.0f);
        glFogf(GL_FOG_END, 200.0f);
        //glEnable(GL_FOG);

        manager.bindActionToEvent(EventType.KeyDown, &onKeyDown);

        // Create font and text
        ft_main = new Font();
        ft_main.init("data/fonts/droid/DroidSans.ttf", 14);

        txt_info = new Text(ft_main);
        txt_info.setPos(16, manager.window_width-32);

        txt_fps = new Text(ft_main);
        txt_fps.setPos(16, 16);

        manager.bindActionToEvent(EventType.Resize, &onResize);

        // Create objects
        scene = new Empty();

        // Create cameras
        camera = new TrackballCamera();
        camera.pitch(45);

        camera3rdPerson = new Empty(scene);
        camera3rdPerson.bsphereRadius = 1.0f;
        Sphere camSphere = new Sphere(camera3rdPerson.bsphereRadius, 12, 6, camera3rdPerson);
        camSphere.visible = false;

        collectibleCost = 
        [
            0: 1,
            1: 10,
            2: 25,
            3: 100,
            4: 500
        ];

        // Create character
        chAMesh = MD5AnimatedMesh("data/character/character.md5mesh");
        chAnimIdle = MD5Animation("data/character/character-idle.md5anim");
        chAnimWalk = MD5Animation("data/character/character-walk.md5anim");
        chAnimJump = MD5Animation("data/character/character-jump.md5anim");
        chAnimFall = MD5Animation("data/character/character-fall.md5anim");

        chPivot = new Empty(scene);
        chPivot.bsphereRadius = 3.0f;
        chPivot.position = Vector3f(0.0f, 20.0f, 10.0f);

        chActor = new MD5Actor(chAMesh, chPivot);
        chActor.setAnimation(&chAnimIdle);
        chActor.roll(180.0f);
        chActor.pitch(-90.0f);
        chActor.position.y -= chPivot.bsphereRadius;

        chColSphere = new Sphere(chPivot.bsphereRadius, 12, 6, chPivot);
        chColSphere.visible = false;

        MD5ArraysAlloc();

        chAnimations[ST_IDLE] = &chAnimIdle;
        chAnimations[ST_WALK] = &chAnimWalk;
        chAnimations[ST_JUMP] = &chAnimJump;
        chAnimations[ST_FALL] = &chAnimFall;

        player = chPivot;

        pushVector = Vector3f(0.0f, 0.0f, 0.0f);

        // Create materials and shaders
        chTextureImage = loadPNG("data/character/character-texture.png");
        chTexture = new Texture(chTextureImage);
        chMaterial = new Material();
        chMaterial.ambientColor = ColorRGBAf(0.9f, 0.9f, 0.9f, 1.0f);
        chMaterial.diffuseColor = ColorRGBAf(0.9f, 0.9f, 0.9f, 1.0f);
        chMaterial.specularColor = ColorRGBAf(1.0f, 1.0f, 1.0f, 1.0f);
        //chMaterial.shininess = 32.0f;
        chMaterial.textures[0] = chTexture;
        //auto chMatShader = new GLSLShader(
        //    readText("data/shaders/phong.vp.glsl"), 
        //    readText("data/shaders/phong.fp.glsl"));
        //chMaterial.shader = chMatShader;

        //SuperImage shadowImg = loadPNG("data/fx/shadow.png");
        shadTexture = new Texture(loadPNG("data/fx/shadow.png"));
        //ColorRGBAf shadowColor = ColorRGBAf(0.0f, 0.0f, 0.0f, 1.0f);


        // Create level
        level = new DatObject("data/arena/arena.dat");

        chPivot.position = level.spawnPosition;
        chPivot.rotation = level.spawnRotation;

        dr = new DatRenderer(level);

        // Create BVH
        bvh = new BVHTree!Triangle(level.tris, 8, Heuristic.SAH);

        // Create items
        do_gem = new DatObject("data/items/gem.dat");
        dr_gem = new DatRenderer(do_gem);
        do_gem.materials[0].ambientColor = do_gem.materials[0].diffuseColor;
        do_gem.materials[0].diffuseColor.a = 0.9f;
        //Material mCollectibleSphere = new Material();
        bb_gemGlow = new Billboard(5.0f, 5.0f, null);
        //auto glowImg = loadPNG("data/fx/glow.png");
        glowTexture = new Texture(loadPNG("data/fx/glow.png"));
    }

    protected void chSetAnimationState(uint st, float sm = 1.0f)
    {
        if (st != chAnimState)
        {
            chActor.smoothSwitchToAnimation(chAnimations[st], sm);
            chAnimState = st;
        }
    }

    void onResize()
    {
        txt_info.setPos(16, manager.window_height-32); 
    }

    void onMouseButtonDown()
    {
        if (manager.event_button == SDL_BUTTON_RIGHT) 
        {
            tempMouseX = manager.mouse_x;
            tempMouseY = manager.mouse_y;
            SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                          cast(ushort)manager.window_height/2);
        }
        else if (manager.event_button == SDL_BUTTON_LEFT) 
        {
        }
        else if (manager.event_button == SDL_BUTTON_MIDDLE) 
        {
            tempMouseX = manager.mouse_x;
            tempMouseY = manager.mouse_y;
            SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                          cast(ushort)manager.window_height/2);
        }
        else if (manager.event_button == SDL_BUTTON_WHEELUP) 
        {
            camera.zoomSmooth(-2.0f,16.0f);
        }
        else if (manager.event_button == SDL_BUTTON_WHEELDOWN) 
        {
            camera.zoomSmooth(2.0f,16.0f);
        }
    }

    override void onUpdate()
    {
        // Camera control
        if (manager.rmb_pressed)
        {
            float turn_m = (cast(float)(manager.window_width/2 - manager.mouse_x))/8.0f;
            float pitch_m = -(cast(float)(manager.window_height/2 - manager.mouse_y))/8.0f;
            camera.pitchSmooth(pitch_m, 16.0f);
            camera.turnSmooth(turn_m, 16.0f);
            SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                          cast(ushort)manager.window_height/2);
        }

        if (manager.mmb_pressed || (manager.lmb_pressed && manager.key_pressed[SDLK_LSHIFT]))
        {
            float shift_x = (cast(float)(manager.window_width/2 - manager.mouse_x))/16.0f;
            float shift_y = (cast(float)(manager.window_height/2 - manager.mouse_y))/16.0f;
            camera.moveSmooth(shift_y, 16.0f);
            camera.strafeSmooth(-shift_x, 16.0f);
            SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                          cast(ushort)manager.window_height/2);
        }

        double delta = min(0.05f, manager.deltaTime);
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

        // "Look" down
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
                        chMaterial.ambientColor = groundLumel;
                        chMaterial.diffuseColor = groundLumel;
                        chMaterial.specularColor = groundLumel;
                        shadAlpha = 0.25f + groundLumel.luminance;
                    }
                }
            }
        });

        // "Look" up
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
            playerGrav += gravity * delta;
        }
        else
        {
            playerJump = 0.0f;
            playerGrav = 0.0f;
            player.position.y = floorHeight + player.boundingSphere.radius;
        }

        if (playerJump > 0.0f) 
            playerJump -= gravity * delta;

        if (player.position.y + player.boundingSphere.radius >= ceilHeight)
        {
            playerJump = 0.0f;
        }

        if (manager.key_pressed[SDLK_UP])
            player.move(speed);
        if (manager.key_pressed[SDLK_DOWN])
            player.move(-speed);
        if (manager.key_pressed[SDLK_LEFT])
            player.turn(220.0f * delta);
        if (manager.key_pressed[SDLK_RIGHT])
            player.turn(-220.0f * delta);
        if (manager.key_pressed[SDLK_SPACE])
        {
            if ((player.position.y - player.boundingSphere.radius) <= floorHeight + 0.1f)
            {
                playerJump = playerJumpCoef;
            }
        }

        pushVector = vectorDecreaseToZero(pushVector, 30.0f * delta);

        player.lift((playerJump - playerGrav) * delta);
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
        if (player.position.y-player.boundingSphere.radius > floorHeight+0.5f)
        {
            chSetAnimationState(ST_FALL, 0.1f);
        }
        else
        {
            if (manager.key_pressed[SDLK_UP])
                chSetAnimationState(ST_WALK);
            else if (manager.key_pressed[SDLK_DOWN])
                chSetAnimationState(ST_WALK);
            else
                chSetAnimationState(ST_IDLE, 0.5f);
        }

        // Draw everything
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glLoadIdentity();

        // Bind camera
        if (freeCamera)
            camera.bind(manager.deltaTime);
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

        glLightfv(GL_LIGHT0, GL_POSITION, vec_lightPos.arrayof.ptr);

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
        shadTexture.bind(manager.deltaTime);
        glDisable(GL_LIGHTING);
        glColor4f(1.0f, 1.0f, 1.0f, shadAlpha);
        glBegin(GL_QUADS);
        glTexCoord2f(0.0f, 1.0f); glVertex3f(-0.5f, -0.5f, 0.0f);
        glTexCoord2f(1.0f, 1.0f); glVertex3f(0.5f, -0.5f, 0.0f);
        glTexCoord2f(1.0f, 0.0f); glVertex3f(0.5f, 0.5f, 0.0f);
        glTexCoord2f(0.0f, 0.0f); glVertex3f(-0.5f, 0.5f, 0.0f);
        glEnd();
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        glEnable(GL_LIGHTING);
        shadTexture.unbind();
        glPopMatrix();

        chMaterial.bind(manager.deltaTime);
        player.draw(manager.deltaTime);
        chMaterial.unbind();

        foreach(c; level.collectibles)
        {
            if (!c.available) continue;
            glPushMatrix();
            glTranslatef(c.position.x, c.position.y, c.position.z);
            glRotatef(gemRotZ, 0.0f, 1.0f, 0.0f);
            glRotatef(30.0f, 1.0f, 0.0f, 0.0f);
            if (c.type == 0)
                dr_gem.render();
            glPopMatrix();
        }

        gemRotZ += 90.0f * manager.deltaTime;

        glPushAttrib(GL_ENABLE_BIT); 
        glDisable(GL_LIGHTING);
        glDepthMask(GL_FALSE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        foreach(c; level.collectibles)
        {
            if (!c.available) continue;
            glowTexture.bind(manager.deltaTime);
            Vector3f toCamera = (camera3rdPerson.position - c.position).normalized;
            if (c.type == 0)
            {
                glColor4f(1.0f, 0.0f, 1.0f, 0.4f);
            }
            bb_gemGlow.position = c.position + toCamera * 1.5f;
            bb_gemGlow.render(manager.deltaTime);
            glowTexture.unbind();
        }
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDepthMask(GL_TRUE);
        glPopAttrib();

        if (freeCamera)
            camera.unbind();
        else
            glPopMatrix();

        // 2D mode
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        glOrtho(0, manager.window_width, 0, manager.window_height, -1, 1);
        glMatrixMode(GL_MODELVIEW);

        glLoadIdentity();

        glDisable(GL_LIGHTING);

        glColor3f(1.0f, 1.0f, 1.0f);
        static char buffer[20] = 0; 
        sprintf(buffer.ptr, "Score: %d", score); 
        txt_info.render(to!string(buffer));
        buffer[] = 0; 
        sprintf(buffer.ptr, "%d FPS", manager.fps); 
        txt_fps.render(to!string(buffer));

        glEnable(GL_LIGHTING);

        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);
    }

    void onKeyDown()
    {
        if (manager.event_key == SDLK_ESCAPE)
        {
            manager.running = false;
        }
    }
}


