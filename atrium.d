module atrium;

import std.stdio;
import std.process;
import std.string;
import std.ascii;
import std.math;
import std.conv;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.math.quaternion;
import dlib.math.utils;
import dlib.image.color;
import dlib.container.array;
import dlib.container.aarray;
import dlib.geometry.triangle;

import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.sdl.sdl;

import dgl.core.interfaces;
import dgl.core.compat;
import dgl.core.event;
import dgl.core.application;
import dgl.core.layer;
import dgl.core.room;
import dgl.ui.ftfont;
import dgl.ui.textline;
import dgl.ui.textlineinput;
import dgl.graphics.tbcamera;
import dgl.graphics.axes;
import dgl.graphics.shapes;
import dgl.graphics.lightmanager;
import dgl.graphics.texture;
import dgl.graphics.entity;
import dgl.graphics.mesh;
import dgl.graphics.scene;
import dgl.templates.freeview;
import dgl.asset.resman;
import dgl.vfs.vfs;
import dgl.graphics.shadow;
import dgl.graphics.shader;
import dgl.graphics.glslshader;
import dgl.graphics.bumpshader;
import dgl.graphics.billboard;

import dmech.world;
import dmech.shape;
import dmech.geometry;
import dmech.bvh;

import game.fpcamera;
import game.cc;
import game.weapon;
import game.gravitygun;
import game.config;

class ScreenSprite: EventListener, Drawable
{
    Texture loadingTex;

    this(EventManager em, Texture tex)
    {
        super(em);
        loadingTex = tex;
    }

    override void draw(double dt)
    {
        loadingTex.bind(dt);
        glColor4f(1, 1, 1, 1);
        glBegin(GL_QUADS);
        glTexCoord2f(0, 1); glVertex2f(0, eventManager.windowHeight);
        glTexCoord2f(0, 0); glVertex2f(0, 0);
        glTexCoord2f(1, 0); glVertex2f(eventManager.windowWidth, 0);
        glTexCoord2f(1, 1); glVertex2f(eventManager.windowWidth, eventManager.windowHeight);
        glEnd();
        loadingTex.unbind();
    }

    override void free()
    {
        Delete(this);
    }
}

class LoadingRoom: Room
{
    Layer layer2d;
    ScreenSprite loadingScreen;
    Texture loadingTex;
    string nextRoomName;
    double counter = 0.0;
    
    this(EventManager em, TestApp app)
    {
        super(em, app);        
        layer2d = addLayer(LayerType.Layer2D);
        
        loadingTex = app.rm.getTexture("ui/loading.png");
        
        loadingScreen = New!ScreenSprite(em, loadingTex);
        layer2d.addDrawable(loadingScreen);
    }
    
    void reset(string name)
    {
        nextRoomName = name;
        counter = 0.5;
    }
    
    override void onUpdate()
    {
        super.onUpdate();
        counter -= eventManager.deltaTime;
        
        if (counter <= 0.0)
        {
            counter = 0.0;
            app.setCurrentRoom(nextRoomName, false);
        }
    }
    
    override void free()
    {
        super.freeContent();
        Delete(this);
    }
}

class PauseRoom: Room
{
    Layer layer2d;
    ScreenSprite pauseScreen;
    Texture pauseTex;

    this(EventManager em, TestApp app)
    {
        super(em, app);
        
        layer2d = addLayer(LayerType.Layer2D);

        pauseTex = app.rm.getTexture("ui/pause.png");
        
        pauseScreen = New!ScreenSprite(em, pauseTex);
        layer2d.addDrawable(pauseScreen);
        
        //TextLineInput text = New!TextLineInput(em, app.rm.getFont("Droid"), Vector2f(10, em.windowHeight - 32));
        //layer2d.addDrawable(text);
    }
    
    override void onKeyDown(int key)
    {
        if (key == SDLK_ESCAPE)
            app.exit();
        else if (key == SDLK_RETURN)
        {
            eventManager.showCursor(false);
            app.setCurrentRoom("scene3d");
        }
    }
    
    override void free()
    {
        super.freeContent();
        Delete(this);
    }
}

class PhysicsEntity: Entity
{
    ShapeComponent shape;
    bool highlight = false;
    
    this(Drawable d, ShapeComponent s)
    {
        super(d, s.position);
        shape = s;
    }
    
    override void draw(double dt)
    {
        transformation = shape.transformation;
        // TODO: local transformation
        super.draw(dt);
    }
    
    override void drawModel(double dt)
    {
    /*
        if (highlight)
        {
            glCullFace(GL_FRONT);
            glShadeModel(GL_FLAT);
            glPushMatrix();
            glScalef(1.05f, 1.05f, 1.05f);
            glDisable(GL_LIGHTING);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE);
            super.drawModel(dt);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            glEnable(GL_LIGHTING);
            glPopMatrix();
            glShadeModel(GL_SMOOTH);
            glCullFace(GL_BACK);
        }
    */
        super.drawModel(dt);
    }
    
    override void free()
    {
        shape = null;
        Delete(this);
    }
}

// TODO: This function is total hack,
// need to rewrite BVH module to handle Triangle ranges,
// and add a method to Scene that will lazily return 
// transformed triangles for entities.
BVHTree!Triangle sceneBVH(Scene scene)
{
    DynamicArray!Triangle tris;

    foreach(i, e; scene.entities)
    {
        if (e.type == 0)
        if (e.meshId > -1 && e.drawable)
        {
            Matrix4x4f mat = e.transformation;

            auto mesh = cast(Mesh)e.drawable;

            if (mesh is null)
                continue;

            foreach(fgroup; mesh.fgroups.data)
            foreach(tri; fgroup.tris.data)
            {
                Triangle tri2 = tri;
                tri2.v[0] = tri.v[0] * mat;
                tri2.v[1] = tri.v[1] * mat;
                tri2.v[2] = tri.v[2] * mat;
                tri2.normal = e.rotation.rotate(tri.normal);
                tri2.barycenter = (tri2.v[0] + tri2.v[1] + tri2.v[2]) / 3;

                tris.append(tri2);
            }
        }
    }

    BVHTree!Triangle bvh = New!(BVHTree!Triangle)(tris, 4);
    tris.free();
    return bvh;
}

Vector2f lissajousCurve(float t)
{
    return Vector2f(sin(t), cos(2 * t));
}

int ATR_EVENT_PICK_PENTAGON = 1;

class Pickable: Entity
{
    EventManager eventManager;
    Vector4f lightPosition;
    Color4f lightDiffuseColor;
    Color4f lightAmbientColor;
    Color4f glowColor;
    float rot = 0.0f;
    Texture glowTex;
    FirstPersonCamera camera;
    
    this(EventManager em, FirstPersonCamera camera, Drawable model, Texture glowTex, Vector3f pos)
    {
        super(model, pos);
        lightPosition = Vector4f(0, 0, 0, 1);
        lightDiffuseColor = Color4f(1, 1, 1, 1);
        lightAmbientColor = Color4f(0, 0, 0, 1);
        glowColor = Color4f(1, 0, 1, 0.7);
        rotation = dlib.math.quaternion.rotation(0, degtorad(-90.0f));
        setTransformation(position, rotation, scaling);
        this.eventManager = em;
        this.camera = camera;
        this.glowTex = glowTex;
    }
    
    override void draw(double dt)
    {       
        if (!visible)
            return;
            
        if (distance(camera.position, position) < 1.0f)
        {
            eventManager.generateUserEvent(ATR_EVENT_PICK_PENTAGON);
            visible = false;
        }
    
        rotation = dlib.math.quaternion.rotation(1, rot) *
                   dlib.math.quaternion.rotation(0, degtorad(-90.0f));
        setTransformation(position, rotation, scaling);
        lightPosition = position + Vector3f(2, 2, 0);
        glEnable(GL_LIGHTING);
        glEnable(GL_LIGHT0);
        glLightfv(GL_LIGHT0, GL_POSITION, lightPosition.arrayof.ptr);
        glLightfv(GL_LIGHT0, GL_SPECULAR, lightDiffuseColor.arrayof.ptr);
        glLightfv(GL_LIGHT0, GL_DIFFUSE, lightDiffuseColor.arrayof.ptr);
        glLightfv(GL_LIGHT0, GL_AMBIENT, lightAmbientColor.arrayof.ptr);
        super.draw(dt);
        glDisable(GL_LIGHTING);
        
        rot += 10.0f * dt;
        if (rot >= 2 * PI)
            rot = 0.0f;
            
        glDisable(GL_LIGHTING);
            
        // Draw glow
        glPushMatrix();
        glDepthMask(GL_FALSE);
        glowTex.bind(dt);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        Vector3f pt = Vector3f(0, 0, 0) * transformation;
        Vector3f n = (camera.transformation.translation - pt).normalized;
        pt += n * 0.5f;
        glColor4fv(glowColor.arrayof.ptr);
        drawBillboard(camera.transformation, pt, 1.0f);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glowTex.unbind();
        glDepthMask(GL_TRUE);
        glPopMatrix();
        
        glEnable(GL_LIGHTING);
    }

    override void freeContent()
    {
        super.freeContent();
    }
    
    override void free()
    {
        freeContent();
        Delete(this);
    }
}

class AnimatedSprite: Drawable
{
    Texture texture;
    uint tileWidth;
    uint tileHeight;
    uint tx = 0;
    uint ty = 0;
    uint numHTiles;
    uint numVTiles;
    float framerate = 1.0f / 25.0f;
    double counter = 0.0;
    Vector2f position;
    
    this(Texture sheetTex, uint w, uint h)
    {
        texture = sheetTex;
        tileWidth = w;
        tileHeight = h;
        numHTiles = texture.width / tileWidth;
        numVTiles = texture.height / tileHeight;
        position = Vector2f(0, 0);
    }
    
    void draw(double dt)
    {
        counter += dt;
        if (counter >= framerate)
        {
            counter = 0.0;
            advanceFrame();
        }
        
        float u = cast(float)(tx * tileWidth) / texture.width;
        float v = cast(float)(ty * tileHeight) / texture.height;
        float w = cast(float)tileWidth / texture.width;
        float h = cast(float)tileHeight / texture.height;
        
        glDisable(GL_DEPTH_TEST);
        glPushMatrix();
        glColor4f(1,1,1,1);
        glTranslatef(position.x, position.y, 0.0f);
        glScalef(tileWidth, tileHeight, 1.0f);
        texture.bind(dt);
        glBegin(GL_QUADS);
        glTexCoord2f(u, v);         glVertex2f(0, 0);
        glTexCoord2f(u + w, v);     glVertex2f(1, 0);
        glTexCoord2f(u + w, v + h); glVertex2f(1, 1);
        glTexCoord2f(u, v + h);     glVertex2f(0, 1);
        glEnd();
        texture.unbind();
        glPopMatrix();
        glEnable(GL_DEPTH_TEST);
    }
    
    void advanceFrame()
    {
        tx++;
        if (tx >= numHTiles)
        {
            tx = 0;
            ty++;
            
            if (ty >= numVTiles)
            {
                ty = 0;
            }
        }
    }

    void free()
    {
        Delete(this);
    }
    
    mixin ManualModeImpl;
}

class Scene3DRoom: Room
{
    Scene sceneLevel;
    Scene sceneCube;
    Scene sceneGravityGun;
    Scene scenePhysics;
    Scene sceneWeapon;
    Scene scenePentagon;
    Scene scenePickables;
    ResourceManager rm;
    Layer layer3d;
    Layer layer2d;

    FirstPersonCamera camera;
    CharacterController ccPlayer;
    bool playerWalking = false;
    GravityGun weapon;

    PhysicsWorld world;
    BVHTree!Triangle bvh;
    enum double timeStep = 1.0 / 60.0;
    
    GeomBox gFloor;
    GeomSphere gSphere;
    GeomBox gBox;
    
    TextLine textLine;
    TextLine pCounterLine;

    Shader shader;
    
    uint numPentagons = 0;
    
    this(EventManager em, TestApp app)
    {
        super(em, app);
        
        rm = New!ResourceManager();
        rm.fs.mount("data/levels/corridor");
        rm.fs.mount("data/items");
        rm.fs.mount("data/shaders");
        rm.fs.mount("data/weapons");
        rm.fs.mount("data/ui");
        scenePhysics = rm.addEmptyScene("physics", false);
        dgl.graphics.mesh.generateTangentVectors = false;
        sceneLevel = rm.loadScene("corridor.dgl2", false);
        dgl.graphics.mesh.generateTangentVectors = true;
        sceneCube = rm.loadScene("box.dgl2", false);
        sceneGravityGun = rm.loadScene("gravity-gun.dgl2", false);
        scenePentagon = rm.loadScene("pentagon.dgl2", false);
        scenePickables = rm.addEmptyScene("pickables", true);
        scenePickables.lighted = false;
        
        sceneLevel.createDynamicLights();
        
        layer3d = New!Layer(em, LayerType.Layer3D);
        addLayer(layer3d);
        
        layer2d = New!Layer(em, LayerType.Layer2D);
        addLayer(layer2d);

        layer3d.addDrawable(rm);
        
        auto font = app.rm.getFont("Droid");
        
        textLine = New!TextLine(font, "FPS: 0", Vector2f(8, 8));
        textLine.color = Color4f(1, 1, 1);
        layer2d.addDrawable(textLine);
        
        world = New!PhysicsWorld();
        bvh = sceneBVH(sceneLevel);
        world.bvhRoot = bvh.root;
        
        // Create floor object
        gFloor = New!GeomBox(Vector3f(100, 1, 100));
        auto bFloor = world.addStaticBody(Vector3f(0, -5, 0));
        auto scFloor = world.addShapeComponent(bFloor, gFloor, Vector3f(0, 0, 0), 1);
        
        gSphere = New!GeomSphere(1.0f);
        gBox = New!GeomBox(Vector3f(1, 1, 1));

        // Create camera
        // TODO: read playerPos from scene data (use entity with a special name)
        Vector3f playerPos = Vector3f(0, 2, -5);
        camera = New!FirstPersonCamera(playerPos);
        camera.turn = 90.0f;
        camera.eyePosition = Vector3f(0, 0.0f, 0);
        camera.gunPosition = Vector3f(0.15f, -0.2f, -0.2f);
        layer3d.addModifier(camera);

        // Create character
        ccPlayer = New!CharacterController(world, playerPos, 1.0f, gSphere);
        ccPlayer.rotation.y = -90.0f;

        if (config["enableShaders"].toInt)
        {
            //string txtVP = rm.readText("normalmapping.vp.glsl");
            //string txtFP = rm.readText("normalmapping.fp.glsl");
            //New!GLSLShader(txtVP, txtFP);
            //Delete(txtVP);
            //Delete(txtFP);
            
            if (isGLSLSupported())
            {
                shader = bumpShader();
        
                auto m = sceneGravityGun.material("matGravityGun");
                if (m)
                {
                    m.shader = shader;
                    m.textures[1] = rm.getTexture("gravity-gun-normal.png");
                    m.specularColor = Color4f(0.9, 0.9, 0.9, 1.0);
                }
        
                m = sceneCube.material("Material");
                if (m)
                {
                    m.shader = shader;
                    m.textures[1] = rm.getTexture("normal.png");
                }
            }
            else
            {
                writeln("GLSL is not available");
                config.set("enableShaders", "0");
            }
        }

        if (config["enableShadows"].toInt)
        {
            if (isShadowmapSupported())
            {
                rm.enableShadows = true;
                rm.shadow = New!ShadowMap(config["shadowMapSize"].toInt, config["shadowMapSize"].toInt);
                rm.shadow.castScene = scenePhysics;
                rm.shadow.receiveScene = sceneLevel;
            }
            else
            {
                writeln("Dynamic shadows are not available");
                config.set("enableShadows", "0");
            }
        }
        else
        {
            scenePhysics.visible = true;
            sceneLevel.visible = true;
        }
        
        // Create weapon
        Entity eGravityGun = sceneGravityGun.entity("objGravityGun");
        assert(eGravityGun !is null);
        Texture glowTex = rm.getTexture("glow.png");
        weapon = New!GravityGun(eGravityGun, glowTex, camera, rm, eventManager, world);
        sceneLevel.addEntity("wGravityGun", weapon);
        
        scenePentagon.material("matPentagon").ambientColor = scenePentagon.material("matPentagon").diffuseColor;
        
        createDynamicObjects();
        
        auto pentaSheet = rm.getTexture("pentagon.png");
        auto pentaSprite = New!AnimatedSprite(pentaSheet, 32, 32);
        pentaSprite.position = Vector2f(8, eventManager.windowHeight - 8 - 32);
        layer2d.addDrawable(pentaSprite);
        
        pCounterLine = New!TextLine(font, "0", Vector2f(8 + 32 + 8, em.windowHeight - 16 - font.height));
        pCounterLine.color = Color4f(1, 1, 1);
        layer2d.addDrawable(pCounterLine);
    }
    
    void createDynamicObjects()
    {
        foreach(i, e; sceneLevel.entities)
        {
            if (e.type == 2) addPentagon(e.position);
            else if (e.type == 3) addBox(e.position);
        }
    }
    
    uint pentIndex = 0;
    Pickable addPentagon(Vector3f position)
    {
        Texture glowTex = rm.getTexture("glow.png");
        Pickable p = New!Pickable(eventManager, camera, scenePentagon.mesh("mPentagon"), glowTex, position);
        scenePickables.addEntity(format("pentagon%s", pentIndex), p);
        pentIndex++;
        return p;
    }
    
    uint boxIndex = 0;
    PhysicsEntity addBox(Vector3f position)
    {
        auto b = world.addDynamicBody(position);
        auto sc = world.addShapeComponent(b, gBox, Vector3f(0, 0, 0), 10.0f);
        auto e = New!PhysicsEntity(sceneCube.mesh("Cube"), sc);
        scenePhysics.addEntity(format("box%s", boxIndex), e);
        boxIndex++;
        return e;
    }
    
    void createBodiesStack(string name, float x, uint n, Geometry g)
    {
        foreach(i; 0..n)
        {
            auto b = world.addDynamicBody(Vector3f(x, 1.5f + i * 2, -(i * 0.4f)));
            auto sc = world.addShapeComponent(b, g, Vector3f(0, 0, 0), 100.0f);
            auto e = New!PhysicsEntity(sceneCube.mesh("Cube"), sc);
            scenePhysics.addEntity(format("%s%s", name, i), e);
        }
    }
    
    override void onKeyDown(int key)
    {
        if (key == SDLK_ESCAPE)
        {
            eventManager.showCursor(true);
            app.setCurrentRoom("pause");
        }
    }

    void cameraControl()
    {        
        float turn_m = -(cast(float)eventManager.windowWidth/2 - eventManager.mouseX)/10.0f;
        float pitch_m = (cast(float)eventManager.windowHeight/2 - eventManager.mouseY)/10.0f;
        camera.pitch += pitch_m;
        camera.turn += turn_m;
        camera.gunPitch += pitch_m * 0.85f;
        eventManager.setMouseToCenter();
    }

    void playerControl()
    {   
        playerWalking = false;
    
        Vector3f forward = camera.transformation.forward;
        Vector3f right = camera.transformation.right;
        
        ccPlayer.rotation.y = camera.turn;
        if (eventManager.keyPressed['w']) { ccPlayer.move(forward, -12.0f); playerWalking = true; }
        if (eventManager.keyPressed['s']) { ccPlayer.move(forward, 12.0f); playerWalking = true; }
        if (eventManager.keyPressed['a']) { ccPlayer.move(right, -12.0f); playerWalking = true; }
        if (eventManager.keyPressed['d']) { ccPlayer.move(right, 12.0f); playerWalking = true; }
        if (eventManager.keyPressed[SDLK_SPACE]) ccPlayer.jump(3.0f);
        
        playerWalking = playerWalking && ccPlayer.onGround;

        weapon.shoot();
    }
    
    float gunSwayTime = 0.0f;

    double time = 0.0;
    override void onUpdate()
    {
        super.onUpdate();

        cameraControl();
        
        time += eventManager.deltaTime;
        if (time >= timeStep)
        {
            time -= timeStep;
            playerControl();
            ccPlayer.update();
            world.update(timeStep);
        }
        
        camera.position = ccPlayer.rbody.position;
        swayControl();
        
        textLine.setText(format("FPS: %s", eventManager.fps));
        
        // FIXME: this gives an error sometimes
        //pCounterLine.setText(format("%s", numPentagons));
        
        pCounterLine.setText(numPentagons.to!string);

        if (config["enableShadows"].toInt)
            rm.shadow.lightPosition = camera.position;
            
        //highlightShootedObject();
    }
    
    void highlightShootedObject()
    {
        //if (weapon.shootedBody is null)
        //{
        //    foreach(i, e; scenePhysics.entities)
        //        e.highlight = false;
        //}
        foreach(i, e; scenePhysics.entities)
        {
            PhysicsEntity pe = cast(PhysicsEntity)e;
            if (pe !is null)
            {
                pe.highlight = false;
                if (weapon.shootedBody !is null)
                foreach(s; weapon.shootedBody.shapes.data)
                {
                    if (s is pe.shape)
                    {
                        pe.highlight = true;
                    }
                }
            }
        }
    }
    
    void swayControl()
    {
        if (playerWalking)
            gunSwayTime += 7.0f * eventManager.deltaTime;
        else
            gunSwayTime += 1.0f * eventManager.deltaTime;
        if (gunSwayTime > 2 * PI)
            gunSwayTime = 0.0f;
        Vector2f gunSway = lissajousCurve(gunSwayTime) / 10.0f;
        
        weapon.position = Vector3f(gunSway.x * 0.1f, gunSway.y * 0.1f, 0.0f);
        
        if (playerWalking)
        {
            camera.eyePosition = Vector3f(0, 1, 0) + 
                Vector3f(gunSway.x, gunSway.y, 0.0f);
            camera.roll = -gunSway.x * 5.0f;
        }
    }
    
    override void onUserEvent(int code) 
    {
        if (code == ATR_EVENT_PICK_PENTAGON)
        {
            writeln("Pick");
            numPentagons++;
        }
    }
    
    override void free()
    {
        super.freeContent();
        if (shader !is null)
            shader.free();
        camera.free();
        ccPlayer.free();
        world.free();
        bvh.free();
        gFloor.free();
        gSphere.free();
        gBox.free();
        Delete(this);
    }
}

class TestApp: RoomApplication
{
    ResourceManager rm;
    LoadingRoom loading;
    Scene3DRoom room3d;
    
    this()
    {
        super();

        exitOnEscapePress = false;
        
        clearColor = Color4f(0.5f, 0.5f, 0.5f);

        rm = New!ResourceManager();
        rm.fs.mount("data");
        
        auto fontDroid18 = New!FreeTypeFont("data/fonts/droid/DroidSans.ttf", 18);
        rm.addFont("Droid", fontDroid18);
        
        rooms = New!(AArray!Room)();
        
        addRoom("pause", New!PauseRoom(eventManager, this));
        setCurrentRoom("pause", false);
        
        loading = New!LoadingRoom(eventManager, this);
        addRoom("loading", loading);

        room3d = New!Scene3DRoom(eventManager, this);
        addRoom("scene3d", room3d);
        eventManager.showCursor(false);
        loadRoom("scene3d");
    }
    
    override void loadRoom(string name, bool deleteCurrent = false)
    {
        setCurrentRoom("loading", deleteCurrent);
        loading.reset(name);
    }
    
    override void freeContent()
    {
        super.freeContent();
        rm.free();
    }
    
    override void free()
    {
        freeContent();
        Delete(this);
    }
}

void main(string[] args)
{
    readConfig();

    writefln("Allocated memory at start: %s", allocatedMemory);
    loadLibraries();
    auto app = New!TestApp();
    app.run();
    app.free();
    writefln("Allocated memory at end: %s", allocatedMemory);
}

