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
import dlib.image.color;
import dlib.container.array;
import dlib.container.aarray;
import dlib.geometry.triangle;

import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.sdl.sdl;

import dgl.core.interfaces;
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
import dgl.graphics.glslshader;
import dgl.graphics.entity;
import dgl.graphics.mesh;
import dgl.graphics.scene;
import dgl.templates.freeview;
import dgl.asset.resman;
import dgl.vfs.vfs;
import dgl.graphics.shadow;

import dmech.world;
import dmech.shape;
import dmech.geometry;
import dmech.bvh;

import game.fpcamera;
import game.cc;
import game.weapon;
import game.gravitygun;

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

class Scene3DRoom: Room
{
    Scene sceneLevel;
    Scene sceneCube;
    Scene sceneGravityGun;
    Scene scenePhysics;
    Scene sceneWeapon;
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

    GLSLShader shader;
    
    this(EventManager em, TestApp app)
    {
        super(em, app);
        
        rm = New!ResourceManager();
        rm.fs.mount("data/levels/gateway");
        rm.fs.mount("data/scenes");
        rm.fs.mount("data/shaders");
        rm.fs.mount("data/weapons");
        sceneLevel = rm.loadScene("gateway.dgl2", false);
        sceneCube = rm.loadScene("cube.dgl2", false);
        sceneGravityGun = rm.loadScene("gravity-gun.dgl2", false);
        scenePhysics = rm.addEmptyScene("physics", false);
        
        layer3d = New!Layer(em, LayerType.Layer3D);
        addLayer(layer3d);
        
        layer2d = New!Layer(em, LayerType.Layer2D);
        addLayer(layer2d);

        layer3d.addDrawable(rm);
        
        textLine = New!TextLine(app.rm.getFont("Droid"), "FPS: 0", Vector2f(8, 8));
        textLine.color = Color4f(1, 1, 1);
        layer2d.addDrawable(textLine);
        
        world = New!PhysicsWorld();
        bvh = sceneBVH(sceneLevel);
        world.bvhRoot = bvh.root;
        
        // Create floor object
        gFloor = New!GeomBox(Vector3f(100, 1, 100));
        auto bFloor = world.addStaticBody(Vector3f(0, -5, 0));
        auto scFloor = world.addShapeComponent(bFloor, gFloor, Vector3f(0, 0, 0), 1);

        sceneLevel.createDynamicLights();

        auto m = sceneCube.materials["Material"];
        if (m)
            m.ambientColor = Color4f(0.5f, 0.5f, 0.5f, 1.0f);
            
        m = sceneGravityGun.materials["matGravityGun"];
        if (m)
            m.ambientColor = Color4f(0.5f, 0.5f, 0.5f, 1.0f);

        gSphere = New!GeomSphere(1.0f);
        gBox = New!GeomBox(Vector3f(1, 1, 1));

        createBodiesStack(3, gBox);

        // Create camera
        Vector3f playerPos = Vector3f(-6, 1.001, 0);
        camera = New!FirstPersonCamera(playerPos);
        camera.turn = 90.0f;
        camera.eyePosition = Vector3f(0, 0.8f, 0);
        camera.gunPosition = Vector3f(0.15f, -0.2f, -0.2f);
        layer3d.addModifier(camera);

        // Create character
        ccPlayer = New!CharacterController(world, playerPos, 1.0f, gSphere);
        ccPlayer.rotation.y = -90.0f;

        // Create weapon
        Entity eGravityGun = sceneGravityGun.entities["objGravityGun"];
        assert(eGravityGun !is null);
        Texture glowTex = rm.getTexture("glow.png");
        weapon = New!GravityGun(eGravityGun, glowTex, camera, rm, eventManager, world);
        sceneLevel.addEntity("wGravityGun", weapon);

/*
        // GLSL shader demo
        string txtVP = rm.readText("phong.vp.glsl");
        string txtFP = rm.readText("phong.fp.glsl");
        //writeln(txtVP);
        shader = New!GLSLShader(txtVP, txtFP);
        Delete(txtVP);
        Delete(txtFP);
        m.shader = shader;
        m.ambientColor = Color4f(0.1f, 0.1f, 0.1f, 1.0f);
*/

        if (enableShadows)
        {
            // TODO: move this check to Shadow class
            if (DerelictGL.isExtensionSupported("GL_ARB_shadow") &&
                DerelictGL.isExtensionSupported("GL_ARB_depth_texture"))
            {
                rm.enableShadows = true;
                rm.shadow = New!ShadowMap(shadowMapSize, shadowMapSize);
                rm.shadow.castScene = scenePhysics;
                rm.shadow.receiveScene = sceneLevel;
            }
            else
            {
                writeln("Dynamic shadows are not available: GL_ARB_shadow and GL_ARB_depth_texture are not supported");
                enableShadows = false;
            }
        }
        else
        {
            scenePhysics.visible = true;
            sceneLevel.visible = true;
        }

        sceneLevel.setMaterialsShadeless(false);
    }
    
    void createBodiesStack(uint n, Geometry g)
    {
        foreach(i; 0..n)
        {
            auto b = world.addDynamicBody(Vector3f(0, 1.5f + i * 2, -(i * 0.4f)));
            auto sc = world.addShapeComponent(b, g, Vector3f(0, 0, 0), 1.0f);
            auto e = New!PhysicsEntity(sceneCube.meshes["Cube"], sc);
            scenePhysics.addEntity(format("stack_body%s", i), e);
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

        if (enableShadows)
            rm.shadow.lightPosition = camera.position;
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
    
    override void free()
    {
        super.freeContent();
        //shader.free();
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
        writeln("Deleting TestApp...");
        rm.free();
    }
    
    override void free()
    {
        freeContent();
        Delete(this);
    }
}

import std.getopt;

// TODO: create configuration manager
uint enableShadows = 1;
uint shadowMapSize = 512;

void readOptions(string[] args)
{
    try
    {
        getopt(args,
            "enableShadows", &enableShadows,
            "shadowMapSize", &shadowMapSize);
    }
    catch(Exception)
    {
        writeln("Illegal option");
    }
}

void main(string[] args)
{
    readOptions(args);

    writefln("Allocated memory at start: %s", allocatedMemory);
    loadLibraries();
    auto app = New!TestApp();
    app.run();
    app.free();
    writefln("Allocated memory at end: %s", allocatedMemory);
}

