module game.scene3d;

import std.stdio;
import std.math;
import std.string;
import std.conv;

import dlib;
import dgl;
import dmech;

import game.fpcamera;
import game.character;
import game.weapon;
import game.gravitygun;
import game.config;
import game.pickable;
import game.physicsentity;
import game.kinematic;
import game.app;

class FramebufferObject: Modifier
{
    GLuint fbo;
    GLuint rbDepth;
    Texture tex;
    
    this()
    {
        tex = New!Texture(512, 512);
    
        // Create the FBO
        glGenFramebuffersEXT(1, &fbo);        
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fbo);  
        
        glGenRenderbuffersEXT(1, &rbDepth);
        glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, rbDepth);
        glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, 512, 512);
        glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, 0);
        
        glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, tex.tex, 0); 
        glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, rbDepth);
        
        GLenum fboStatus = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);       
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
    }
    
    void bind(double dt)
    {
        // Enable render-to-texture
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fbo);  
    }
    
    void unbind()
    {
        // Re-enable rendering to the window
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
        glBindTexture(GL_TEXTURE_2D, 0);
    }
    
    ~this()
    {
        glDeleteRenderbuffersEXT(1, &rbDepth);
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
        glDeleteFramebuffersEXT(1, &fbo);
        tex.free();
    }
    
    void free()
    {
        Delete(this);
    }
}

class FBOLayer: Layer
{
    FramebufferObject fbo;
    bool drawToScreen = true;

    this(EventManager emngr, LayerType type)
    {
        super(emngr, type);
        fbo = New!FramebufferObject();
    }
    
    override void draw(double dt)
    {        
        fbo.bind(dt);

        glViewport(0, 0, 512, 512);

        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClearDepth(1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();

        if (type == LayerType.Layer2D)
            glOrtho(0, eventManager.windowWidth, 0, eventManager.windowHeight, 0, 1);
        else
            gluPerspective(60, aspectRatio, 0.1, 400.0);
        glMatrixMode(GL_MODELVIEW);
        
        glLoadIdentity();
        glColor4f(1, 1, 1, 1);

        foreach(i, m; modifiers.data)
            m.bind(dt);
        foreach(i, drw; drawables.data)
            drw.draw(dt);
        foreach(i, m; modifiers.data)
            m.unbind();

        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);

        fbo.unbind();
        
        if (drawToScreen)
            super.draw(dt);
    }
    
    ~this()
    {
        fbo.free();
    }
    
    override void free()
    {
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
            if ("ghost" in e.props)
            {
                if (e.props["ghost"].toBool)
                    continue;
            }
        
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

class MovingPlatfrom: KinematicController
{
    this(PhysicsWorld world, Vector3f pos, Geometry geom)
    {
        super(world, pos, geom);
    }

    Vector3f p1 = Vector3f(38, 10, 5);
    Vector3f p2 = Vector3f(38, -2.0f, 5);
    float t = 0.0f;
    int moveFwd = 1;

    void update(double dt)
    {
        t += 0.1f * dt * moveFwd;
        if (t >= 1.0f) { moveFwd = -1; }
        else if (t <= 0.0f) { moveFwd = +1; }

        Vector3f newPosition = lerp(p1, p2, t);
        moveToPosition(newPosition, dt);
    }

    override void free()
    {
        Delete(this);
    }
}

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

class DoorEntity: Entity
{
    PhysicsWorld world;
    Entity doorFrame;
    Entity door1;
    Entity door2;
    Geometry doorGeom;
    RigidBody doorBody;
    DynamicArray!RigidBody openerBodies;
    Vector3f t1;
    Vector3f t2;
    Vector3f pos1 = Vector3f(0, 0, 0);
    Vector3f pos2 = Vector3f(6, 0, 0);
    bool opened = false;
    int key = 0;
    
    this(Scene doorScene, PhysicsWorld w, Vector3f pos, Quaternionf rot)
    {
        super(pos);

        doorFrame = doorScene.entity("doorFrame");
        door1 = doorScene.entity("door1");
        door2 = doorScene.entity("door2");
        
        world = w;
        doorGeom = New!GeomBox(Vector3f(2, 2, 0.1f));
       
        doorBody = world.addStaticBody(pos);
        doorBody.orientation = rot;
        auto sc = world.addShapeComponent(doorBody, doorGeom, Vector3f(0, 0, 0), 100.0f);
        
        t1 = Vector3f(0, 0, 0);
        t2 = Vector3f(0, 0, 0);
        
        setTransformation(pos, rot, Vector3f(1, 1, 1));
    }

    void addOpener(RigidBody rb)
    {
        openerBodies.append(rb);
    }
    
    float t = 0.0f;
    override void drawModel(double dt)
    {
        opened = false;
        foreach(b; openerBodies)
        {
            if ((position - b.position).lengthsqr < 10.0f)
            {
                opened = true;
                break;
            }
        }
            
        doorBody.active = !opened;
        
        if (opened)
        {
            t1 = lerp(pos1, pos2, t);
            t2 = lerp(pos1, -pos2, t);
            if (t < 1.0f)
                t += 1.0f * dt;
        }
        else
        {
            t1 = lerp(pos1, pos2, t);
            t2 = lerp(pos1, -pos2, t);
            if (t > 0.0f)
                t -= 1.0f * dt;
        }
    
        if (modifier !is null)
            modifier.bind(dt);
            
        if (doorFrame !is null) doorFrame.draw(dt);
        
        glPushMatrix();
        glTranslatef(t1.x, t1.y, t1.z);
        if (door1 !is null) door1.draw(dt);
        glPopMatrix();
        
        glPushMatrix();
        glTranslatef(t2.x, t2.y, t2.z);
        if (door2 !is null) door2.draw(dt);
        glPopMatrix();
        
        if (debugDraw)
        {
            drawPoint();
        }
        
        if (modifier !is null)
            modifier.unbind();
    }
    
    override void free()
    {
        Delete(this);
    }

    ~this()
    {
        Delete(doorGeom);
        openerBodies.free();
    }
}

class Scene3DRoom: Room
{
    Scene sceneLevel;
    Scene sceneCube;
    Scene sceneGravityGun;
    Scene sceneDoor;
    Scene scenePhysics;
    Scene sceneWeapon;
    Scene scenePentagon;
    Scene scenePickables;
    ResourceManager rm;
    Layer layer3d;
    //Layer blurLayer;
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

    GLSLShader shShadeless;
    GLSLShader shSimple;
    GLSLShader shTex;
    GLSLShader shBump;
    GLSLShader shParallax;
    
    uint numPentagons = 0;
    
    //ShapeSphere sSphere;
    //Entity eCastSphere;
    //ShapeComponent scSphere;
    //GeomSphere gSphere2;
    
    Font font;
    
    ShapeBox sBox;
    GeomBox gBox2;
    MovingPlatfrom platform;
    PhysicsEntity eBox;
    
    AnimatedSprite pentaSprite;
    Sprite crosshairSprite;
    
    ScreenSprite renderedSprite;
    ScreenSprite renderedSprite2;
    
    ScreenSprite vignette;
    
    GLSLShader sBlurh;
    GLSLShader sBlurv;
        
    Material gunMaterial;
    Material glowingMaterial;
    
    DynamicArray!Region regions;
    
    bool shadersEnabled()
    {
        return config["enableShaders"].toInt && isGLSLSupported();
    }
    
    bool glowEnabled()
    {       
        return config["enableGlow"].toInt && shadersEnabled();
    }
    
    bool shadowsEnabled()
    {
        return config["enableShadows"].toInt && isShadowmapSupported();
    }
    
    bool glslShadowsEnabled()
    {
        return config["enableGLSLShadows"].toInt && shadowsEnabled();
    }
    
    this(EventManager em, GameApp app)
    {
        super(em, app);
        
        rm = New!ResourceManager();
        rm.fs.mount("data/levels/new"); // level files override default ones
        rm.fs.mount("data/default/items");
        rm.fs.mount("data/default/weapons");
        rm.fs.mount("data/default/shaders");
        rm.fs.mount("data/default/ui");
        
        // Load objects
        scenePhysics = rm.addEmptyScene("physics", false);
        sceneLevel = rm.loadScene("walls.dgl2", false);
        sceneCube = rm.loadScene("box.dgl2", false);
        sceneGravityGun = rm.loadScene("gravity-gun-2.dgl2", false);
        scenePentagon = rm.loadScene("pentagon.dgl2", false);
        scenePickables = rm.addEmptyScene("pickables", true);
        scenePickables.lighted = false;
        sceneDoor = rm.loadScene("door.dgl2", false);
        
        sceneLevel.createDynamicLights();
        
        string txtVP, txtFP;
        
        if (glowEnabled())
        {
            FBOLayer fboLayer = New!FBOLayer(em, LayerType.Layer3D);
            layer3d = fboLayer;
            addLayer(layer3d);
        
            FBOLayer blurLayer = New!FBOLayer(em, LayerType.Layer2D);
            blurLayer.drawToScreen = false;
            addLayer(blurLayer);
        
            sBlurh = loadShader(em, "blur.vp.glsl", "hblur.fp.glsl");
            sBlurv = loadShader(em, "blur.vp.glsl", "vblur.fp.glsl");

            renderedSprite = New!ScreenSprite(em, fboLayer.fbo.tex);
            renderedSprite.material.shader = sBlurh;
            blurLayer.addDrawable(renderedSprite);
        
            renderedSprite2 = New!ScreenSprite(em, blurLayer.fbo.tex);
            renderedSprite2.material.shader = sBlurv;
            renderedSprite2.material.additiveBlending = true;
        }
        else
        {
            layer3d = New!Layer(em, LayerType.Layer3D);
            addLayer(layer3d);
        }
        
        layer3d.addDrawable(rm);
        
        layer2d = New!Layer(em, LayerType.Layer2D);
        addLayer(layer2d);
        
        if (glowEnabled())
            layer2d.addDrawable(renderedSprite2);
        
        vignette = New!ScreenSprite(em, rm.getTexture("vignette.png"));
        layer2d.addDrawable(vignette);
        
        font = app.rm.getFont("Droid");
        textLine = New!TextLine(font, "FPS: 0", Vector2f(8, 8));
        textLine.color = Color4f(1, 1, 1);
        layer2d.addDrawable(textLine);
        
        auto pentaSheet = rm.getTexture("pentagon.png");
        pentaSprite = New!AnimatedSprite(pentaSheet, 32, 32);
        pentaSprite.position = Vector2f(8, eventManager.windowHeight - 8 - 32);
        layer2d.addDrawable(pentaSprite);
        
        crosshairSprite = New!Sprite(rm.getTexture("crosshair-2.png"), 64, 64);
        crosshairSprite.position = Vector2f(em.windowWidth/2 - 32, em.windowHeight/2 - 32);
        layer2d.addDrawable(crosshairSprite);
        
        pCounterLine = New!TextLine(font, "0", Vector2f(8 + 32 + 8, em.windowHeight - 16 - font.height));
        pCounterLine.color = Color4f(1, 1, 1);
        layer2d.addDrawable(pCounterLine);
        
        // Create physics world
        world = New!PhysicsWorld();
        world.positionCorrectionIterations = 20;
        bvh = sceneBVH(sceneLevel);
        world.bvhRoot = bvh.root;
        
        // Create floor object
        gFloor = New!GeomBox(Vector3f(100, 1, 100));
        auto bFloor = world.addStaticBody(Vector3f(0, -5, 0));
        auto scFloor = world.addShapeComponent(bFloor, gFloor, Vector3f(0, 0, 0), 1);
        
        // Create geoms
        gSphere = New!GeomSphere(1.0f);
        gBox = New!GeomBox(Vector3f(0.75, 0.75, 0.75));

        // Create camera
        // TODO: read playerPos from scene data (use entity with a special name)
        Vector3f playerPos = Vector3f(20, 2, 0);
        if (sceneLevel.entity("spawnPos"))
        {
            playerPos = sceneLevel.entity("spawnPos").position;
        }
        camera = New!FirstPersonCamera(playerPos);
        camera.turn = -90.0f;
        camera.eyePosition = Vector3f(0, 0.0f, 0);
        camera.gunPosition = Vector3f(0.15f, -0.2f, -0.2f);
        layer3d.addModifier(camera);

        // Create character
        ccPlayer = New!CharacterController(world, playerPos, 1.0f, gSphere);
        ccPlayer.rotation.y = -90.0f;
        characterGravity = ccPlayer.rbody.gravity;

        // Create moving platform
        sBox = New!ShapeBox(Vector3f(3, 0.25f, 2));
        gBox2 = New!GeomBox(Vector3f(3, 0.25f, 2));
        platform = New!MovingPlatfrom(world, Vector3f(0.0f, 1.5f, 0.0f), gBox2);
        eBox = New!PhysicsEntity(sBox, platform.rbody, platform.rbody.shapes.data[0]);
        scenePhysics.addEntity("ePlatform", eBox);

        // Apply bump shader
        if (shadersEnabled())
        {
            shBump = uberShader(em);
            shBump.setParamBool("textureEnabled", true);
            shBump.setParamBool("bumpEnabled", true);
            shBump.setParamBool("parallaxEnabled", false);
/*
            gunMaterial = sceneGravityGun.material("matGravityGun");
            if (gunMaterial)
            {
                gunMaterial.shader = shBump;
                gunMaterial.textures[1] = rm.getTexture("gravity-gun-normal.png");
                gunMaterial.textures[2] = rm.getTexture("gravity-gun-emit.png");
                //gunMaterial.ambientColor = Color4f(0.3, 0.5, 0.7, 1.0);
                //gunMaterial.specularColor = Color4f(0.9, 0.9, 0.9, 1.0);
                gunMaterial.emissionColor.w = 0.0f;
            }
        */
            auto matCube = sceneCube.material("Material");
            if (matCube)
            {
                matCube.shader = shBump;
                matCube.textures[1] = rm.getTexture("normal.png");
                matCube.textures[2] = rm.getTexture("emit.png");
                //m.ambientColor = Color4f(0.5, 0.5, 0.5, 1.0);
                matCube.emissionColor.w = 1.0f;
            }

            shParallax = uberShader(em);
            shParallax.setParamBool("textureEnabled", true);
            shParallax.setParamBool("bumpEnabled", true);
            shParallax.setParamBool("parallaxEnabled", true);
            sceneLevel.material("mGlowing").shader = shParallax;
            
            shTex = uberShader(em);
            shTex.setParamBool("textureEnabled", true);
            shTex.setParamBool("bumpEnabled", false);
            shTex.setParamBool("parallaxEnabled", false);
            
            shSimple = uberShader(em);
            shSimple.setParamBool("textureEnabled", false);
            shSimple.setParamBool("bumpEnabled", false);
            shSimple.setParamBool("parallaxEnabled", false);
            
            shShadeless = uberShader(em);
            shShadeless.setParamBool("shadeless", true);
            shShadeless.setParamBool("textureEnabled", false);
            shShadeless.setParamBool("bumpEnabled", false);
            shShadeless.setParamBool("parallaxEnabled", false);
            
            foreach(i, m; sceneLevel.materials)
            {
                if (m.textures[1])
                    m.shader = shParallax;
                else if (m.textures[0])
                    m.shader = shTex;
                else if (!m.shadeless)
                    m.shader = shSimple;
                else
                    m.shader = shShadeless;
                    
                if (m.textures[2])
                    m.emissionColor.w = 1.0f;
            }
            
            foreach(i, m; sceneGravityGun.materials)
            {
                if (m.textures[1])
                    m.shader = shParallax;
                else if (m.textures[0])
                    m.shader = shTex;
                else if (!m.shadeless)
                    m.shader = shSimple;
                else
                    m.shader = shShadeless;
                m.emissionColor.w = 0.0f;
            }
            
            foreach(i, m; sceneDoor.materials)
            {
                if (m.textures[1])
                    m.shader = shParallax;
                else if (m.textures[0])
                    m.shader = shTex;
                else if (!m.shadeless)
                    m.shader = shSimple;
                else
                    m.shader = shShadeless;
                m.emissionColor.w = 0.0f;
            }
            
            sceneGravityGun.material("mBlackPlastic").diffuseColor = Color4f(0, 0, 0, 1);
            sceneGravityGun.material("mWhiteMetalDoubleSided").doubleSided = true;
            
            glowingMaterial = sceneLevel.material("mGlowing");
        }

        // Create shadow
        if (shadowsEnabled())
        {
            rm.enableShadows = true;
            rm.shadow = New!ShadowMap(config["shadowMapSize"].toInt, config["shadowMapSize"].toInt, camera);
            rm.shadow.castScene = scenePhysics;
            rm.shadow.receiveScene = sceneLevel;
        }
        else
        {
            sceneLevel.visible = true;
            scenePhysics.visible = true;
        }
                
        createDynamicObjects();
        
        // Add special objects (regions and doors)
        foreach(i, e; sceneLevel.entities)
        {
            foreach(k, v; e.props)
            {
                //writeln(k, ": ", v);
                if ("zeroGravity" in e.props &&
                    "bbox" in e.props)
                {
                    if (e.props["zeroGravity"].toBool)
                    {
                        Vector3f bboxHSize = e.props["bbox"].toVector3f * 0.5f;
                        regions.append(Region(e.getPosition, bboxHSize, RegionType.ZeroGravity));
                    }
                }
            }
            
            if ("door" in e.props)
            {
                if (e.props["door"].toBool)
                {
                    DoorEntity de = addDoor(e.getPosition, e.getRotation);
                    de.addOpener(ccPlayer.rbody);
                    foreach(spe; scenePhysics.entities)
                    {
                        PhysicsEntity pe = cast(PhysicsEntity)spe;
                        if (pe) de.addOpener(pe.rbody);
                    }
                }
            }
        }
        
        // Create weapon
        Entity eGravityGun = sceneGravityGun.entity("objGravityGun");
        assert(eGravityGun !is null);
        Texture glowTex = rm.getTexture("glow.png");
        weapon = New!GravityGun(eGravityGun, glowTex, camera, rm, eventManager, world);
        sceneLevel.addEntity("wGravityGun", weapon);
        
        scenePentagon.material("matPentagon").ambientColor = scenePentagon.material("matPentagon").diffuseColor;
        
        rm.lm.useUpdateTreshold = true;
        
        glEnable(GL_FOG);
        glFogi(GL_FOG_MODE, GL_LINEAR);
        Color4f fogColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
        glFogfv(GL_FOG_COLOR, fogColor.arrayof.ptr);
        glFogf(GL_FOG_DENSITY, 0.35f);
        glFogf(GL_FOG_START, 1.0f);
        glFogf(GL_FOG_END, 20.0f);
    }
    
    GLSLShader loadShader(EventManager em, string vp, string fp)
    {
        string txtVP = rm.readText(vp);
        string txtFP = rm.readText(fp);
        auto shader = New!GLSLShader(em, txtVP, txtFP);
        Delete(txtVP);
        Delete(txtFP);
        return shader;
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
        b.stopThreshold = 0.1f;
        auto sc = world.addShapeComponent(b, gBox, Vector3f(0, 0, 0), 20.0f);
        auto e = New!PhysicsEntity(sceneCube.mesh("Cube"), b, sc);
        scenePhysics.addEntity(format("box%s", boxIndex), e);
        
        auto light = rm.lm.addPointLight(e.position);
        light.diffuseColor = Color4f(1.0f, 0.5f, 0.0f, 1.0f); 
        e.light = light;
        
        boxIndex++;
        return e;
    }
    
    uint doorIndex = 0;
    DoorEntity addDoor(Vector3f position, Quaternionf rotation)
    {
        auto e = New!DoorEntity(sceneDoor, world, position, rotation);
        sceneLevel.addEntity(format("door%s", doorIndex), e);
        doorIndex++;
        return e;
    }
    
    void createBodiesStack(string name, float x, uint n, Geometry g)
    {
        foreach(i; 0..n)
        {
            auto b = world.addDynamicBody(Vector3f(x, 1.5f + i * 2, -(i * 0.4f)));
            auto sc = world.addShapeComponent(b, g, Vector3f(0, 0, 0), 100.0f);
            auto e = New!PhysicsEntity(sceneCube.mesh("Cube"), b, sc);
            scenePhysics.addEntity(format("%s%s", name, i), e);
        }
    }
    
    override void onEnter()
    {
        eventManager.showCursor(false);
        eventManager.setMouseToCenter();
    }
    
    bool mouseControl = true;
    
    override void onFocusLoss()
    {
        mouseControl = false;
        eventManager.showCursor(true);
    }
    
    override void onFocusGain()
    {
        mouseControl = true;
        eventManager.showCursor(false);
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
        int hWidth = eventManager.windowWidth / 2;
        int hHeight = eventManager.windowHeight / 2;
        float turn_m = -(hWidth - eventManager.mouseX) * 0.1f;
        float pitch_m = (hHeight - eventManager.mouseY) * 0.1f;
        camera.pitch += pitch_m;
        camera.turn += turn_m;
        float gunPitchCoef = 0.95f;
        camera.gunPitch += pitch_m * gunPitchCoef;
        
        float pitchLimitMax = 70.0f;
        float pitchLimitMin = -70.0f;
        if (camera.pitch > pitchLimitMax)
        {
            camera.pitch = pitchLimitMax;
            camera.gunPitch = pitchLimitMax * gunPitchCoef;
        }
        else if (camera.pitch < pitchLimitMin)
        {
            camera.pitch = pitchLimitMin;
            camera.gunPitch = pitchLimitMin * gunPitchCoef;
        }
        
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
        
        if (gunMaterial)
        {
            if (weapon.shootedBody)
            {
                if (gunMaterial.emissionColor.w < 1.0f)
                    gunMaterial.emissionColor.w += 5.0f * timeStep;
            }
            else
            {
                if (gunMaterial.emissionColor.w > 0.0f)
                    gunMaterial.emissionColor.w -= 2.0f * timeStep;
            }
        }
        
        if (glowingMaterial)
        {
            glowingMaterial.emissionColor.w = cos(anim) * 0.5f + 0.5f;
            anim += 2.0f * timeStep;
            if (anim >= PI * 2.0f)
                anim = 0.0f;
        }
    }
    
    Vector3f characterGravity = Vector3f(0, 0, 0);
    
    float anim = 0.0f;
    
    float camSwayTime = 0.0f;
    float gunSwayTime = 0.0f;

    double time = 0.0;
    override void onUpdate()
    {
        super.onUpdate();
        
        if (!mouseControl)
            return;

        cameraControl();
        
        time += eventManager.deltaTime;
        if (time >= timeStep)
        {
            time -= timeStep;
            playerControl();
            ccPlayer.update();
            platform.update(timeStep);
            world.update(timeStep);
            
            handleGravity();
        }
        
        camera.position = ccPlayer.rbody.position;
        rm.lm.referencePoint = camera.position;
        swayControl();
        
        textLine.setText(format("FPS: %s", eventManager.fps));
        
        // FIXME: this gives an error sometimes
        //pCounterLine.setText(format("%s", numPentagons));
        
        pCounterLine.setText(numPentagons.to!string);

        if (shadowsEnabled())
        {
            rm.shadow.lightPosition = camera.position;
            
            //if (glslShadowsEnabled())
            //    smShader.invCamView = camera.transformation;
        }
    }
    
    void handleGravity()
    {
        bool zeroGravity;
        foreach(e; scenePhysics.entities)
        {
            PhysicsEntity pe = cast(PhysicsEntity)e;
            if (!pe)
                continue;
                    
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
            
        zeroGravity = false;
        foreach(r; regions)
        {
            if (r.isPointInside(weapon.sparks.source))
                zeroGravity = true;
        }
            
        if (zeroGravity)
            weapon.enableGravity(false);
        else
            weapon.enableGravity(true);
    }
    
    override void onRedraw()
    {
        rm.shadow.renderShadowMap(eventManager.deltaTime);
        super.onRedraw();
    }
    
    void highlightShootedObject()
    {
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
            
        Vector2f gunSway = lissajousCurve(gunSwayTime) / 10.0f;
                
        weapon.position = Vector3f(gunSway.x * 0.1f, gunSway.y * 0.1f, 0.0f);
        
        Vector2f camSway = lissajousCurve(camSwayTime) / 10.0f;          
        camera.eyePosition = Vector3f(0, 1, 0) + 
            Vector3f(camSway.x, camSway.y, 0.0f);
        camera.roll = -camSway.x * 5.0f;
    }
    
    override void onUserEvent(int code) 
    {
        if (code == ATR_EVENT_PICK_PENTAGON)
        {
            numPentagons++;
        }
    }
    
    override void onResize(int width, int height)
    {
        super.onResize(width, height);
        pentaSprite.position = Vector2f(8, height - 8 - 32);
        crosshairSprite.position = Vector2f(width/2 - 32, height/2 - 32);
        pCounterLine.position = Vector2f(8 + 32 + 8, height - 16 - font.height);
    }
    
    ~this()
    {
        if (shShadeless !is null) shShadeless.free();
        if (shSimple !is null) shSimple.free();
        if (shTex !is null) shTex.free();
        if (shBump !is null) shBump.free();
        if (shParallax !is null) shParallax.free();
        
        camera.free();
        ccPlayer.free();
        world.free();
        bvh.free();
        gFloor.free();
        gSphere.free();
        gBox.free();
        sBox.free();
        gBox2.free();
        platform.free();
        
        if (sBlurh !is null) sBlurh.free();
        if (sBlurv !is null) sBlurv.free();
        
        regions.free();
    }
    
    override void free()
    {        
        Delete(this);
    }
}
