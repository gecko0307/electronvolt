module atrium;

import std.stdio;
import std.math;
import std.random;

import dlib.core.memory;
import dlib.container.array;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.math.quaternion;
import dlib.math.utils;
import dlib.math.interpolation;
import dlib.geometry.aabb;
import dlib.image.color;

import dgl.core.api;
import dgl.core.event;
import dgl.core.interfaces;
import dgl.core.application;
import dgl.graphics.pass;
import dgl.graphics.scene;
import dgl.graphics.entity;
import dgl.graphics.shapes;
import dgl.graphics.material;
import dgl.graphics.shader;
import dgl.graphics.texture;
import dgl.graphics.light;
import dgl.graphics.state;
import dgl.templates.app3d;
import dgl.templates.freeview;
import dgl.ui.ftfont;
import dgl.ui.textline;
import dgl.text.cbuffer;
import dgl.text.dml;
import dgl.asset.resource;
import dgl.asset.dgl2;
import dgl.graphics.mesh;
import dgl.graphics.shadow;
import dgl.graphics.sprite;
import dgl.graphics.rtt;

import dlib.geometry.triangle;
import dmech.world;
import dmech.geometry;
import dmech.rigidbody;
import dmech.shape;
import dmech.bvh;
import dmech.raycast;

import game.character;
import game.fpcamera;
import game.modelbvh;
import game.physicsentity;
import game.kinematic;
import game.weapon;
import game.gravitygun;
import game.audio;

class BoxEntity: PhysicsEntity
{
    Light light;
    
    AudioPlayer player;
    ALuint hitSoundBuf;
    ALuint hitShound;
    bool playHitSound = false;

    this(Drawable d, RigidBody rb, uint shapeIndex = 0)
    {
        super(d, rb, shapeIndex);
    }
    
    void setHitSound(AudioPlayer player, ALuint buf)
    {
        this.player = player;
        hitShound = player.addSource(buf, Vector3f(0, 0, 0));
        playHitSound = true;
    }
    
    override void update(double dt)
    {
        super.update(dt);
        if (light)
            light.position = transformation.translation;
    }
    
    override void onHardCollision(float velProj)
    {
        if (playHitSound)
        {
            if (!player.isSourcePlaying(hitShound))
            {
                player.setSourcePosition(hitShound, getPosition());
                float volume = clamp(velProj / 8.0f, 0.0f, 1.0f);
                player.setSourceVolume(hitShound, volume);
                player.playSource(hitShound);
            }
        }
    }
}

Vector2f lissajousCurve(float t)
{
    return Vector2f(sin(t), cos(2 * t));
}

class PauseScreen: EventListener, Drawable
{
    this(EventManager emngr)
    {
        super(emngr);
    }

    void draw(double dt)
    {
        //glPushAttrib(GL_ENABLE_BIT);
        //glDisable(GL_LIGHTING);
        glColor4f(0, 0, 0, 0.75f);
        glBegin(GL_QUADS);
        glVertex2f(0, 0);
        glVertex2f(eventManager.windowWidth, 0);
        glVertex2f(eventManager.windowWidth, eventManager.windowHeight);
        glVertex2f(0, eventManager.windowHeight);
        glEnd();
        glColor4f(1, 1, 1, 1);
        //glPopAttrib();
    }
}

class AnimLoadingScreen: LoadingScreen
{
    Texture animationTexture;
    float progress = 0.0f;
    
    this(EventManager emngr, Texture loadingtex, Texture animTex)
    {
        super(emngr, loadingtex);
        animationTexture = animTex;
    }
    
    override void update(double dt)
    {
        progress -= 360.0f * dt;
    }

    override void draw(double dt)
    {
        super.draw(dt);
        
        if (animationTexture)
            animationTexture.bind(dt);

        glPushMatrix();
        glTranslatef(cast(float)eventManager.windowWidth * 0.5f - 16,
                     cast(float)eventManager.windowHeight * 0.3f, 0);
        glRotatef(progress, 0.0f, 0.0f, 1.0f);
        glColor4f(1, 1, 1, 1);
        glBegin(GL_QUADS);
        glTexCoord2f(0, 0); glVertex2f(-16, 16);
        glTexCoord2f(0, 1); glVertex2f(-16, -16);
        glTexCoord2f(1, 1); glVertex2f(16, -16);
        glTexCoord2f(1, 0); glVertex2f(16, 16);
        glEnd();
        glPopAttrib();
        glPopMatrix();

        if (animationTexture)
            animationTexture.unbind();
    }
}

class BlurPass: RTTPass
{
    Scene scene;
    BlurFX blur;
    Texture originalTexture;
    
    this(uint w, uint h, Texture origTex, EventManager emngr)
    {
        scene = New!Scene();
        super(w, h, false, scene, emngr);
        originalTexture = origTex;
        
        blur = New!BlurFX(emngr, origTex);
        scene.createEntity(blur);
    }
    
    static bool supported()
    {
        return RTTPass.supported() && Material.isGLSLSupported();
    }
    
    ~this()
    {
        Delete(scene);
        Delete(blur);
    }
}

class BlurFX: EventListener, Drawable
{
    Material mat;
    float size;
    Shader blurShader;
    
    string blurVP = "
void main()
{	
    gl_Position = ftransform();		
    gl_TexCoord[0] = gl_MultiTexCoord0;
}
    ";
    
    string blurFP = "
uniform sampler2D dgl_Texture0;
uniform vec2 dgl_WindowSize;

void main(void)
{     
    vec4 total = vec4(0.0, 0.0, 0.0, 1.0);
    vec2 pix = gl_FragCoord.xy;
    vec2 invScreenSize = vec2(1.0 / dgl_WindowSize.x, 1.0 / dgl_WindowSize.y);
    const float radius = 8.0;
    
    const vec4 zero = vec4(0.0, 0.0, 0.0, 0.0);

    vec4 c;
    for (float ky = -radius; ky <= radius; ky++)
    for (float kx = -radius; kx <= radius; kx++)
    {
        c = texture2D(dgl_Texture0, gl_TexCoord[0].xy + vec2(kx, ky) * invScreenSize);
        float luma = c.r *  0.2 + c.g *  0.7 + c.b * 0.1;
        total += (luma > 0.5)? c : zero;
    }

    total /= radius * radius * 4.0;
        
    gl_FragColor = total;
    gl_FragColor.a = 0.9;
}
    ";
    
    this(EventManager emngr, Texture tex)
    {
        super(emngr);
        mat = New!Material();
        mat.textures[0] = tex;
        mat.shadeless = true;
        size = tex.width;
        blurShader = New!Shader(blurVP, blurFP);
        mat.setShader(blurShader);
    }
    
    ~this()
    {
        Delete(mat);
        Delete(blurShader);
    }
    
    void draw(double dt)
    {
        mat.bind(dt);
        glColor4f(1, 1, 1, 1);
        glDisable(GL_MULTISAMPLE_ARB);
        glBegin(GL_QUADS);
        glTexCoord2f(0, 0); glVertex2f(0, 0);
        glTexCoord2f(1, 0); glVertex2f(size, 0);
        glTexCoord2f(1, 1); glVertex2f(size, size);
        glTexCoord2f(0, 1); glVertex2f(0, size);
        glEnd();
        glEnable(GL_MULTISAMPLE_ARB);
        mat.unbind();
    }
}

class Grass: Drawable
{
    override void draw(double dt)
    {
        glColor4f(1, 1, 0, 1);
        glBegin(GL_LINES);
        glVertex3f(0, 0, 0);
        glVertex3f(0, 2, 0);
        glEnd();
        glColor4f(1, 1, 1, 1);
    }
}

enum SHADOW_GROUP = 100;

enum RegionType
{
    ZeroGravity
}

struct Region
{
    AABB aabb;
    RegionType type;
    
    this(Vector3f pos, Vector3f hSize, RegionType t)
    {
        aabb = AABB(pos, hSize);
        type = t;
    }
    
    bool isPointInside(Vector3f p)
    {
        return aabb.containsPoint(p);
    }
}

class TestApp: Application3D
{
    FreeTypeFont font;
    Freeview freeview;
    
    //Entity player;
    
    ShadowMapPass shadow;
    
    PhysicsWorld world;
    BVHTree!Triangle bvh;
    enum fixedTimeStep = 1.0 / 60.0;
    GeomBox gFloor;
    GeomBox gBox;
    GeomCylinder gBarrel;
    GeomSphere gSphere;
    GeomBox gSensor;
    GeomBox gPlatform;
    KinematicController platform;

    FirstPersonView fpsView;
    CharacterController ccPlayer;
    Vector3f characterGravity = Vector3f(0, 0, 0);
    
    TextLine text;

    Entity ePause;
    AnimLoadingScreen animlsrc;
    Texture animTex;
    
    RTTPass rtt3d;
    RTTPass blurPass;
    
    Color4f envColor = Color4f(0, 0, 0, 1); //Color4f(0.25f, 0.5f, 0.75f, 1.0f);
    Color4f ambColor = Color4f(0.1f, 0.1f, 0.0f, 1.0f);
    
    //Grass grass;
    
    Weapon weapon;
    
    DynamicArray!PhysicsEntity physicsEntities;
    DynamicArray!Region regions;
    
    Texture crosshairTex;
    Sprite crosshairSprite;
    
    Material glowingMaterial;
    
    AudioPlayer player;

    this()
    {    
        super();
        
        player = new AudioPlayer();
        
        player.setListener(Vector3f(0, 0, 0), Vector3f(0, 0, 1), Vector3f(0, 1, 0));
        
        GenericSound footstep1 = loadWAV("data/sounds/footstep1.wav");
        GenericSound footstep2 = loadWAV("data/sounds/footstep2.wav");
        GenericSound hitMetal = loadWAV("data/sounds/metal-hit.wav");
        footstepBuffer[0] = player.addBuffer(footstep1);
        footstepBuffer[1] = player.addBuffer(footstep2);
        metalHitBuffer = player.addBuffer(hitMetal);
        footstepSound = player.addSource(footstepBuffer[0], Vector3f(0, 0, 0));
        //metalHitSound = player.addSource(hitMetalBuf, Vector3f(0, 0, 0));

        pass3d.clearColor = envColor;
        Quaternionf sunRotation = rotationQuaternion(0, degtorad(-120.0f));

        if (ShadowMapPass.supported && ShadowMapPass.isShadowsEnabled)
        {
            uint ssize = shadowMapSize();
            PipelineState.shadowMapSize = ssize;
            shadow = New!ShadowMapPass(ssize, ssize, scene3d, SHADOW_GROUP, eventManager);
            shadow.lightRotation = sunRotation;
            shadow.depth = 1;
            addPass3D(shadow);
        }

        //LightManager.sunColor = Color4f(0.8f, 0.5f, 0.3f, 1); //envColor;
        //LightManager.sunDirection = sunRotation.rotate(Vector3f(0, 0, 1));
        //LightManager.sunDirection.w = 0.0f;
        //LightManager.sunEnabled = true;
                
        Material.setFogColor(Color4f(0.3, 0.2, 0.1, 1)); 
        Material.setFogDistance(10.0f, 30.0f);
        Material.setFogEnabled(true);

        if (BlurPass.supported && glowEnabled)
        {
            uint glowMapSize = 128; // TODO: read from config, use two-pass blur
            rtt3d = New!RTTPass(glowMapSize, glowMapSize, true, scene3d, eventManager);
            rtt3d.clearColor = envColor;
            addPass3D(rtt3d);
            rtt3d.depth = -1;

            blurPass = New!BlurPass(glowMapSize, glowMapSize, rtt3d.tex, eventManager);
            blurPass.clearColor = envColor;
            addPass2D(blurPass);
            blurPass.depth = -2;
            
            ScreenSprite srect = New!ScreenSprite(eventManager, blurPass.tex);
            registerObject("srect", srect);
            createEntity2D(srect);
            srect.material.additiveBlending = true;
        }
        
        setDefaultLoadingImage("data/ui/loading.png");
        
        animTex = resourceManager.loadTexture("data/ui/progress.png");
        animlsrc = New!AnimLoadingScreen(eventManager, defaultLoadingScreen.loadingTexture, animTex);
        loadingScreen = animlsrc;
        
        mountDirectory("data/levels/001");
        mountDirectory("data/models");
        
        string level = "level.dgl2";
        string box = "box.dgl2";
        string gravityGun = "manipulator.dgl2";

        addModelResource(level);
        addModelResource(box);
        addModelResource(gravityGun);
        loadResources();
        
        if (!Material.isShadersEnabled)
        {            
            foreach(i, m; getModel(level).materialsById)
            {
                m.textures[1] = null;
                m.textures[2] = null;
            }
            
            foreach(i, m; getModel(box).materialsById)
            {
                m.textures[1] = null;
                m.textures[2] = null;
            }
            
            foreach(i, m; getModel(gravityGun).materialsById)
            {
                m.textures[1] = null;
                m.textures[2] = null;
            }
        }
        else
        {
            //glowingMaterial = getMaterial(level, "mGlowing");
        }

        scene3d.transparentSort = true;
        
        world = New!PhysicsWorld(1000);
        world.positionCorrectionIterations = 20;
        bvh = modelBVH(getModel(level));
        world.bvhRoot = bvh.root;
        
        gFloor = New!GeomBox(Vector3f(40, 1, 40));
        auto bFloor = world.addStaticBody(Vector3f(0, -1, 0));
        world.addShapeComponent(bFloor, gFloor, Vector3f(0, -5, 0), 1.0f);

        gBox = New!GeomBox(Vector3f(0.75, 0.75, 0.75));
        auto boxMesh = getMesh(box, "meshBox");
        
        foreach(name, e; getModel(level).entitiesByName)
        {
            if (e.type == 3)
            {
                PhysicsEntity pe = addPhysicsEntity(e.position, boxMesh, gBox, name);
                pe.groupID = SHADOW_GROUP;
            }
            else if (e.type == 0)
            {
                addEntity3D(e);
            }
            
            if (e.model is null)
            {
                e.shadeless = true;
            }
            
            if ("dropShadow" in e.props)
            {
                if (e.props["dropShadow"].toBool)
                    e.groupID = SHADOW_GROUP;
            }
            
            if ("zeroGravity" in e.props && "bbox" in e.props)
            {
                if (e.props["zeroGravity"].toBool)
                {
                    Vector3f bboxHSize = e.props["bbox"].toVector3f * 0.5f;
                    regions.append(Region(e.getPosition, bboxHSize, RegionType.ZeroGravity));
                }
            }
            /*
            if ("scatterType" in e.props &&
                "bbox" in e.props)
            {
                if (e.props["scatterType"].toInt == 1)
                {
                    int scatterNum = 5;
                    if ("scatterNum" in e.props)
                    {
                        scatterNum = e.props["scatterNum"].toInt;
                    }
                    
                    Vector3f bboxHSize = e.props["bbox"].toVector3f * 0.5f;
                    scatterObject(e.position, bboxHSize, scatterNum, grass);
                }
            }
            */
        }


        //addEntitiesFromModel(level);
        
        // Create character
        Vector3f playerPos = Vector3f(20, 2, 0);
        if (getModel(level).entitiesByName["spawnPos"])
            playerPos = getModel(level).entitiesByName["spawnPos"].position;
        gSphere = New!GeomSphere(1.0f);
        gSensor = New!GeomBox(Vector3f(0.5f, 0.25f, 0.5f));
        ccPlayer = New!CharacterController(world, playerPos, 80.0f, gSphere);
        ccPlayer.rotation.y = 90.0f;
        characterGravity = ccPlayer.rbody.gravity;
        ccPlayer.addSensor(gSensor, Vector3f(0.0f, -0.75f, 0.0f));
/*
        gPlatform = New!GeomBox(Vector3f(2.0f, 0.25f, 2.0f));
        platform = New!KinematicController(world, Vector3f(5, 2, 10), gPlatform);
        auto sPlatform = New!ShapeBox(Vector3f(2.0f, 0.25f, 2.0f));
        registerObject("sPlatform", sPlatform);
        PhysicsEntity pePlatform = New!PhysicsEntity(sPlatform, platform.rbody);
        pePlatform.groupID = SHADOW_GROUP;
        addEntity3D(pePlatform);
        registerObject("pePlatform", pePlatform);
*/
        fpsView = New!FirstPersonView(eventManager, playerPos);
        fpsView.camera.eyePosition = Vector3f(0, 0, 0);
        fpsView.camera.gunPosition = Vector3f(0.15f, -0.2f, -0.2f);
        fpsView.camera.turn = 90.0f;
        
        auto eGG = getEntity(gravityGun, "eWeapon");
        //auto eGGFX = getEntity(gravityGun, "eShootFX");
        //auto bulletStart = getEntity(gravityGun, "eBulletStart");
        Vector3f bulletStartPos = Vector3f(0, 0, 0);
        //bulletStartPos = bulletStart.position;
        auto eGravityGun = New!GravityGun(eGG, /*eGGFX*/ null, fpsView.camera, eventManager, lightManager, world, bulletStartPos, player);
        weapon = eGravityGun;
        registerObject("eGravityGun", eGravityGun);
        eGravityGun.transparent = true;
        addEntity3D(eGravityGun);
        
        addLightsFromModel(level);

        freeview = New!Freeview(eventManager);

        font = New!FreeTypeFont("data/fonts/droid/DroidSans.ttf", 20);
        registerObject("font", font);

        text = New!TextLine(font, "FPS: 0");
        text.color = CWhite;
        registerObject("text", text);
        auto eText = createEntity2D(text);
        eText.position = Vector3f(10, 10, 0);
        
        crosshairTex = resourceManager.loadTexture("data/ui/crosshair.png");
        crosshairSprite = New!Sprite(crosshairTex, 64, 64);
        crosshairSprite.position = Vector2f(eventManager.windowWidth/2 - 32, eventManager.windowHeight/2 - 32);
        crosshairSprite.color = Color4f(1, 1, 1, 0.15f);
        createEntity2D(crosshairSprite);
        
        auto pauseScreen = New!PauseScreen(eventManager);
        registerObject("pauseScreen", pauseScreen);
        ePause = createEntity2D(pauseScreen);
        ePause.visible = false;
        
        scene3d.sortByTransparency();
        
        Material.uberShader.shadowEnabled = true;
    }
    
    ALuint footstepBuffer[2];
    uint footstepIndex = 0;
    ALuint footstepSound;
    ALuint metalHitBuffer;
    
    void scatterObject(Vector3f center, Vector3f aabb, int num, Drawable drw)
    {
        Vector3f pmin = center - aabb;
        Vector3f pmax = center + aabb;
        
        foreach(i; 0..num)
        {
            Vector3f rpos;
            rpos.x = uniform(pmin.x, pmax.x);
            rpos.y = center.y;
            rpos.z = uniform(pmin.z, pmax.z);
            Vector3f norm = Vector3f(0, 1, 0);
            CastResult cr;
            if (world.raycast(rpos, Vector3f(0, -1, 0), 100.0f, cr, false, true))
            {
                rpos.y = cr.point.y;
                norm = cr.normal;
            }
            
            auto e = createEntity3D(drw);
            e.transparent = true;
            e.position = rpos;
            Quaternionf rotNorm = rotationBetween(Vector3f(0, 1, 0), norm);
            e.rotation = rotNorm *
                         rotationQuaternion(0, degtorad(-90.0f));
            float s = uniform(0.5f, 1.0f);
            e.scaling = Vector3f(s, s, s);
            e.groupID = SHADOW_GROUP;
        }
    }
    
    uint shadowMapSize()
    {
        if ("fxShadowMapSize" in config)
            return config["fxShadowMapSize"].toUInt();
        else
            return 512;
    }
    
    bool glowEnabled()
    {
        if ("fxGlowEnabled" in config)
            return config["fxGlowEnabled"].toBool();
        else
            return false;
    }

    ~this()
    {
        Delete(freeview);
        
        Delete(world);
        Delete(gFloor);
        Delete(gBox);

        Delete(gSphere);
        Delete(gSensor);
        //Delete(gPlatform);
        Delete(ccPlayer);
        //Delete(platform);
        Delete(fpsView);
        
        Delete(animlsrc);
        Delete(animTex);
        
        Delete(crosshairTex);
        Delete(crosshairSprite);
        
        physicsEntities.free();
        regions.free();
        
        bvh.free();
        
        player.close();
    }
    
    PhysicsEntity addPhysicsEntity(Vector3f pos, Drawable model, Geometry geom, string name, bool addLight = true)
    {
        auto rb = world.addDynamicBody(pos, 0.0f);
        auto sc = world.addShapeComponent(rb, geom, Vector3f(0, 0, 0), 50.0f);
        BoxEntity pe = New!BoxEntity(model, rb);
        pe.setHitSound(player, metalHitBuffer);

        if (addLight)
        {
            auto light = addPointLight(pos);
            light.diffuseColor = Color4f(1.0f, 0.5f, 0.0f, 1.0f); 
            pe.light = light;
        }
        
        physicsEntities.append(pe);
        addEntity3D(pe);
        registerObject(name, pe);
        return pe;
    }
    
    override void onResize(int width, int height)
    {
        super.onResize(width, height);
        
        crosshairSprite.position = Vector2f(width/2 - 32, height/2 - 32);
    }
    
    override void onMouseButtonDown(int button)
    {
        super.onMouseButtonDown(button);
    }

    override void onKeyDown(int key)
    {
        if (key == SDLK_RETURN)
        {
            fpsView.switchMouseControl();
            fpsView.paused = !fpsView.paused;
            ePause.visible = !ePause.visible;
        }
        else if (key == SDLK_ESCAPE)
        {
            exit();
        }
    }
    
    bool playerWalking = false;
    
    void playerControl()
    {   
        playerWalking = false;
    
        Vector3f forward = fpsView.camera.transformation.forward;
        Vector3f right = fpsView.camera.transformation.right;
        
        ccPlayer.rotation.y = fpsView.camera.turn;
        enum float speed = 8.0f;
        if (eventManager.keyPressed['w']) { ccPlayer.move(forward, -speed); playerWalking = true; }
        if (eventManager.keyPressed['s']) { ccPlayer.move(forward, speed); playerWalking = true; }
        if (eventManager.keyPressed['a']) { ccPlayer.move(right, -speed); playerWalking = true; }
        if (eventManager.keyPressed['d']) { ccPlayer.move(right, speed); playerWalking = true; }
        if (eventManager.keyPressed[SDLK_SPACE]) ccPlayer.jump(3.0f);
        
        playerWalking = playerWalking && ccPlayer.onGround;

        weapon.shoot();
    }
    
    float camSwayTime = 0.0f;
    float gunSwayTime = 0.0f;
    
    void swayControl()
    {
        if (playerWalking && !ccPlayer.flyMode)
        {
            gunSwayTime += 7.0f * eventManager.deltaTime;
            camSwayTime += 7.0f * eventManager.deltaTime;
        }
        else
        {
            gunSwayTime += 1.0f * eventManager.deltaTime;
        }
        
        if (gunSwayTime >= 2.0f * PI)
            gunSwayTime = 0.0f;
        if (camSwayTime >= 2.0f * PI)
            camSwayTime = 0.0f;
        
        Vector2f gunSway = Vector2f(0, 0);
        gunSway = lissajousCurve(gunSwayTime) / 10.0f;
                
        weapon.position = Vector3f(gunSway.x * 0.1f, gunSway.y * 0.1f, 0.0f);
        
        Vector2f camSway = lissajousCurve(camSwayTime) / 10.0f;          
        fpsView.camera.eyePosition = Vector3f(0, 1, 0) + 
            Vector3f(camSway.x, camSway.y, 0.0f);
        fpsView.camera.roll = -camSway.x * 5.0f;
    }
    
    double time = 0.0;
    CharBuffer!50 cbFPS;
    
    double shadowUpdateTimer = 0.0;

    float t = 0.0f;
    //float angle = 0.0f;
    bool platformDir = true;
    
    float anim = 0.0f;
    
    override void onUpdate(double dt)
    {
        swayControl();
        
        fpsView.update(dt);
        setCameraMatrix(fpsView.getCameraMatrix());
    
        super.onUpdate(dt);

        cbFPS.format!"FPS: %i"(eventManager.fps);
        text.text = cbFPS.asString;
        
        time += dt;
        if (time >= fixedTimeStep)
        {
            time -= fixedTimeStep;
            playerControl();
            if (platformDir)
                t += 0.1f * fixedTimeStep;
            else
                t -= 0.1f * fixedTimeStep;
            if (t >= 1.0f || t <= 0.0f)
                platformDir = !platformDir;

            //Vector3f platformPos = lerp(Vector3f(5, 2, 10), Vector3f(5, 2, -10), t);
            //platform.rbody.angularVelocity = Vector3f(0, 0.2, 0);
            //platform.position = platformPos;
            //platform.update(fixedTimeStep);
            ccPlayer.update();
            world.update(fixedTimeStep);
            
            fpsView.camera.position = ccPlayer.rbody.position;
            fpsView.camera.turn += ccPlayer.selfTurn;
            
            handleGravity();
        }            
        
        if (rtt3d)
            rtt3d.modelViewMatrix = pass3d.modelViewMatrix;

        if (shadow)
        {
            Vector3f pos = fpsView.camera.position - fpsView.camera.transformation.forward * 7.0f;
            shadow.lightPosition = pos;
            shadow.update(dt);
        }
        
        if (glowingMaterial)
        {
            glowingMaterial.emissionColor.w = cos(anim) * 0.5f + 0.5f;
            anim += 2.0f * dt;
            if (anim >= PI * 2.0f)
                anim = 0.0f;
        }
        
        if (playerWalking && !ccPlayer.flyMode)
        {
            if (!player.isSourcePlaying(footstepSound))
            {
                player.setSourceBuffer(footstepSound, footstepBuffer[footstepIndex]);
                footstepIndex = !footstepIndex;
                player.playSource(footstepSound);
            }
        }
        
        player.setListener(
            fpsView.camera.position,
            -fpsView.camera.transformation.forward, 
            fpsView.camera.transformation.up);
    }
    
    void handleGravity()
    {
        bool zeroGravity;
        foreach(i, pe; physicsEntities)
        {                    
            zeroGravity = false;
                
            foreach(r; regions)
            {
                if (r.isPointInside(pe.getPosition))
                    zeroGravity = true;
            }
                
            if (zeroGravity)
            {
                pe.rbody.useOwnGravity = true;
                pe.rbody.gravity = Vector3f(0, 0, 0);
            }
            else
            {
                pe.rbody.useOwnGravity = false;
            }
        }
            
        zeroGravity = false;
        foreach(r; regions)
        {
            if (r.isPointInside(ccPlayer.rbody.position))
                zeroGravity = true;
        }
            
        if (zeroGravity)
            ccPlayer.enableGravity(false);
        else
            ccPlayer.enableGravity(true);
        

        GravityGun gg = cast(GravityGun)weapon;
        if (gg)
        {
            if (gg.sparks.haveParticlesToDraw)
            {
                foreach(ref p; gg.sparks.particles)
                if (p.time < p.lifetime)
                {
                    zeroGravity = false;
                    foreach(r; regions)
                    {
                        if (r.isPointInside(p.position))
                            zeroGravity = true;
                    }
                    
                    if (zeroGravity)
                        p.gravityVector = Vector3f(0.0f, 0.0f, 0.0f);
                    else
                        p.gravityVector = Vector3f(0.0f, -1.0f, 0.0f);
                }
            }        
        }
    }
    
    override void onRedraw(double dt)
    {
        if (shadow)
	        shadow.bind(fpsView.camera.getTransformation());       
        super.onRedraw(dt);
        if (shadow)
            shadow.unbind();
    }
}

version = Debug;

void main(string[] args)
{
    version(Debug) writefln("Allocated memory at start: %s", allocatedMemory);  
    initDGL();
    auto app = New!TestApp();
    app.run();
    Delete(app);
    deinitDGL();
    version(Debug) writefln("Allocated memory at end: %s", allocatedMemory);
    printMemoryLog();
}
