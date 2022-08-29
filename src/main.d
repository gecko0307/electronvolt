module main;

import std.stdio;
import std.conv;
import std.math;
import std.random;

import dagon;
import dagon.ext.ftfont;
import dagon.ext.newton;
import soloud;

Vector2f lissajousCurve(float t)
{
    return Vector2f(sin(t), cos(2 * t));
}

class GameplayScene: Scene, NewtonRaycaster
{
    Game game;
    Soloud audio;
    
    FontAsset aFontDroidSans14;
    ImageAsset aEnvmap;
    
    OBJAsset aBoxMesh;
    TextureAsset aBoxDiffuse;
    TextureAsset aBoxNormal;
    TextureAsset aBoxRoughnessMetallic;
    
    //OBJAsset aLevel;
    ImageAsset aHeightmap;
    TextureAsset aRocks;
    TextureAsset aRocksNormal;
    TextureAsset aDirt;
    TextureAsset aDirtNormal;
    TextureAsset aDirtSplatmap;
    //PackageAsset aGravitygun;
    TextureAsset aTexColorTable;

    Entity cameraPivot;
    Camera camera;
    FirstPersonViewComponent fpview;

    Light sun;
    Color4f sunColor = Color4f(1.0f, 0.9f, 0.8f, 1.0f);
    float sunPitch = -20.0f;
    float sunTurn = 180.0f;

    NewtonPhysicsWorld world;
    NewtonBodyComponent[] cubeBodyControllers;
    size_t numCubes = 50;
    NewtonBodyComponent[] sphereBodyControllers;
    size_t numSpheres = 20;
    
    NewtonRigidBody cubeBody;

    Entity eCharacter;
    NewtonCharacterComponent character;

    TextLine text;
    
    WavStream music;

    this(Game game, Soloud audio)
    {
        super(game);
        this.game = game;
        this.audio = audio;
    }

    ~this()
    {
        if (cubeBodyControllers.length)
            Delete(cubeBodyControllers);
        if (sphereBodyControllers.length)
            Delete(sphereBodyControllers);
        
        music.free();
    }

    override void beforeLoad()
    {
        music = WavStream.create();
        music.load("data/music/threads.mp3");
        
        aFontDroidSans14 = this.addFontAsset("data/font/DroidSans.ttf", 14);
        aBoxMesh = addOBJAsset("data/box/box.obj");
        aBoxDiffuse = addTextureAsset("data/box/box-diffuse.png");
        aBoxNormal = addTextureAsset("data/box/box-normal.png");
        aBoxRoughnessMetallic = addTextureAsset("data/box/box-roughness-metallic.png");
        
        //aLevel = addOBJAsset("data/building/building.obj");
        aEnvmap = addImageAsset("data/mars.png");
        
        aHeightmap = addImageAsset("data/terrain/heightmap.png");
        aRocks = addTextureAsset("data/terrain/rocks-albedo.png");
        aRocksNormal = addTextureAsset("data/terrain/rocks-normal.png");
        aDirt = addTextureAsset("data/terrain/dirt-albedo.png");
        aDirtNormal = addTextureAsset("data/terrain/dirt-normal.png");
        aDirtSplatmap = addTextureAsset("data/terrain/dirt-splatmap.png");
        
        //aGravitygun = addPackageAsset("data/gravitygun/gravitygun.asset");
        
        aTexColorTable = addTextureAsset("data/lut.png");
    }

    override void afterLoad()
    {
        world = New!NewtonPhysicsWorld(eventManager, assetManager);

        world.loadPlugins("./");

        cameraPivot = addEntity();
        fpview = New!FirstPersonViewComponent(eventManager, cameraPivot);
        camera = addCamera(cameraPivot);
        game.renderer.activeCamera = camera;

        environment.backgroundColor = Color4f(0.9f, 0.8f, 1.0f, 1.0f);
        
        auto envCubemap = New!Texture(assetManager);
        envCubemap.createFromEquirectangularMap(aEnvmap.image, 1024);
        envCubemap.enableRepeat = false;
        environment.ambientMap = envCubemap;
        environment.ambientEnergy = 0.4f;
        environment.fogColor = Color4f(0.651f, 0.553f, 0.6f, 1.0f);
        environment.fogEnd = 500.0f;
        
        game.deferredRenderer.ssaoEnabled = true;
        game.deferredRenderer.ssaoPower = 4.0f;
        game.deferredRenderer.ssaoRadius = 0.25f;
        game.deferredRenderer.ssaoDenoise = 1.0f;
        game.deferredRenderer.occlusionBufferDetail = 1.0f;
        game.postProcessingRenderer.fxaaEnabled = true;
        game.postProcessingRenderer.depthOfFieldEnabled = true;
        game.postProcessingRenderer.fStop = 1.0f;
        game.postProcessingRenderer.motionBlurEnabled = true;
        game.postProcessingRenderer.glowEnabled = false;
        game.postProcessingRenderer.glowThreshold = 1.0f;
        game.postProcessingRenderer.glowIntensity = 0.2f;
        game.postProcessingRenderer.glowRadius = 7;
        game.postProcessingRenderer.tonemapper = Tonemapper.Unreal;
        game.postProcessingRenderer.exposure = 1.0f;
        game.postProcessingRenderer.lutEnabled = true;
        game.postProcessingRenderer.colorLookupTable = aTexColorTable.texture;
        game.postProcessingRenderer.lensDistortionEnabled = true;
        
        sun = addLight(LightType.Sun);
        sun.position.y = 50.0f;
        sun.shadowEnabled = true;
        sun.energy = 10.0f;
        sun.scatteringEnabled = true;
        sun.scatteringUseShadow = true;
        sun.scattering = 0.3f;
        sun.mediumDensity = 0.02f;
        sun.scatteringMaxRandomStepOffset = 0.055f;
        sun.color = sunColor;
        sun.rotation =
            rotationQuaternion!float(Axis.y, degtorad(sunTurn)) *
            rotationQuaternion!float(Axis.x, degtorad(sunPitch));

        auto light1 = addLight(LightType.AreaSphere);
        light1.castShadow = false;
        light1.position = Vector3f(4, 6.5, -4);
        light1.color = Color4f(1.0f, 0.5f, 0.0f, 1.0f);
        light1.energy = 20.0f;
        light1.radius = 0.4f;
        light1.volumeRadius = 10.0f;
        light1.specular = 0.0f;
        
        auto light2 = addLight(LightType.AreaSphere);
        light2.castShadow = false;
        light2.position = Vector3f(-10, 2.5, -4);
        light2.color = Color4f(1.0f, 0.5f, 0.0f, 1.0f);
        light2.energy = 15.0f;
        light2.radius = 0.2f;
        light2.volumeRadius = 10.0f;
        light2.specular = 0.0f;
        
        auto light3 = addLight(LightType.AreaSphere);
        light3.castShadow = false;
        light3.position = Vector3f(-14, 2.5, 11);
        light3.color = Color4f(1.0f, 0.5f, 0.0f, 1.0f);
        light3.energy = 10.0f;
        light3.radius = 0.2f;
        light3.volumeRadius = 10.0f;
        light3.specular = 0.0f;

        auto eSky = addEntity();
        auto psync = New!PositionSync(eventManager, eSky, camera);
        eSky.drawable = New!ShapeBox(Vector3f(1.0f, 1.0f, 1.0f), assetManager);
        eSky.scaling = Vector3f(100.0f, 100.0f, 100.0f);
        eSky.layer = EntityLayer.Background;
        eSky.material = New!Material(assetManager);
        eSky.material.depthWrite = false;
        eSky.material.useCulling = false;
        eSky.material.baseColorTexture = envCubemap;
        
        auto box = New!NewtonBoxShape(Vector3f(0.625, 0.607, 0.65), world);
        auto boxMat = addMaterial();
        boxMat.baseColorTexture = aBoxDiffuse.texture;
        boxMat.normalTexture = aBoxNormal.texture;
        boxMat.roughnessMetallicTexture = aBoxRoughnessMetallic.texture;

        cubeBodyControllers = New!(NewtonBodyComponent[])(numCubes);
        foreach(i; 0..cubeBodyControllers.length)
        {
            auto eCube = addEntity();
            eCube.drawable = aBoxMesh.mesh;
            eCube.material = boxMat;
            eCube.position = Vector3f(3, i * 1.5, 5);
            cubeBodyControllers[i] = eCube.makeDynamicBody(world, box, 500.0f);
            cubeBodyControllers[i].rigidBody.raycastable = true;
        }

        eCharacter = addEntity();
        eCharacter.position = Vector3f(0, 10, 20);
        character = eCharacter.makeCharacter(world, 1.8f, 80.0f);
        
        /*
        useEntity(aGravitygun.entity);
        aGravitygun.entity.setParent(camera);
        foreach(name, entityAsset; aGravitygun.entities)
        {
            auto entity = entityAsset.entity;
            entity.blurMask = 0.0f;
            useEntity(entity);
        }
        aGravitygun.entity.position = Vector3f(0.15, -0.2, -0.2);
        */
        
        /*
        auto levelShape = New!NewtonMeshShape(aLevel.mesh, world);
        auto eLevel = addEntity();
        eLevel.drawable = aLevel.mesh;
        eLevel.turn(45);
        auto matLevel = New!Material(assetManager);
        matLevel.roughness = 0.3f;
        eLevel.material = matLevel;
        auto levelBody = world.createStaticBody(levelShape);
        auto levelBodyController = New!NewtonBodyComponent(eventManager, eLevel, levelBody);
        */
        
        auto heightmap = New!ImageHeightmap(aHeightmap.image, 1.0f, assetManager);
        uint terrainRes = 512;
        auto terrain = New!Terrain(terrainRes, 64, heightmap, assetManager);
        Vector3f terrainScale = Vector3f(0.5f, 30.0f, 0.5f);
        auto heightmapShape = New!NewtonHeightmapShape(heightmap, terrainRes, terrainRes, terrainScale, world);
        auto eTerrain = addEntity();
        eTerrain.position = Vector3f(-128, 0, -128);
        eTerrain.makeStaticBody(world, heightmapShape);
        auto eTerrainVisual = addEntity(eTerrain);
        eTerrainVisual.dynamic = false;
        eTerrainVisual.solid = true;
        
        auto terrainMaterial = environment.terrainMaterial;
        
        auto layer1 = terrainMaterial.addLayer();
        layer1.baseColorTexture = aRocks.texture;
        layer1.normalTexture = aRocksNormal.texture;
        layer1.roughnessFactor = 0.5f;
        layer1.textureScale = Vector2f(60, 60);
        
        auto layer2 = terrainMaterial.addLayer();
        layer2.baseColorTexture = aDirt.texture;
        layer2.normalTexture = aDirtNormal.texture;
        layer2.roughnessFactor = 0.7f;
        layer2.maskTexture = aDirtSplatmap.texture;
        layer2.textureScale = Vector2f(70, 70);
        
        eTerrainVisual.material = terrainMaterial;
        eTerrainVisual.drawable = terrain;
        eTerrainVisual.scaling = terrainScale;

        text = New!TextLine(aFontDroidSans14.font, "0", assetManager);
        text.color = Color4f(1.0f, 1.0f, 1.0f, 0.7f);
        auto eText = addEntityHUD();
        eText.drawable = text;
        eText.position = Vector3f(16.0f, 30.0f, 0.0f);
        
        int voice = audio.play(music);
        audio.setLooping(voice, true);
        
        eventManager.showCursor(false);
        fpview.active = true;
    }

    override void onKeyDown(int key)
    {
        if (key == KEY_ESCAPE)
            application.exit();
        else if (key == KEY_RETURN)
        {
            fpview.active = !fpview.active;
            eventManager.showCursor(!fpview.active);
            fpview.prevMouseX = eventManager.mouseX;
            fpview.prevMouseY = eventManager.mouseY;
        }
    }
    
    override void onMouseButtonDown(int button)
    {
        if (button == MB_LEFT)
        {
            if (cubeBody)
            {
                cubeBody = null;
            }
            else
            {
                raycast(character.eyePoint, character.eyePoint - camera.directionAbsolute * 30.0f);
            }
        }
        else if (button == MB_RIGHT)
        {
            if (cubeBody)
            {
                Vector3f f = camera.directionAbsolute * -50000.0f;
                cubeBody.addForce(f);
                cubeBody = null;
            }
            else
            {
                raycast(character.eyePoint, character.eyePoint - camera.directionAbsolute * 30.0f);
                if (cubeBody)
                {
                    Vector3f f = camera.directionAbsolute * -50000.0f;
                    cubeBody.addForce(f);
                    cubeBody = null;
                }
            }
        }
    }
    
    float closestHit = 1.0f;
    
    bool raycast(Vector3f pstart, Vector3f pend)
    {
        closestHit = 1.0f;
        world.raycast(pstart, pend, this);
        return (closestHit < 1.0f);
    }
    
    float onRayHit(NewtonRigidBody nbody, Vector3f hitPoint, Vector3f hitNormal, float t)
    {
        if (nbody.dynamic && t < closestHit)
        {
            cubeBody = nbody;
            closestHit = t;
        }
        return t;
    }
    
    bool playerWalking = false;
    float camSwayTime = 0.0f;
    float gunSwayTime = 0.0f;
    
    override void onUpdate(Time t)
    {
        updateCharacter();
        updateWeaponMechanics(t);
        world.update(t.delta);
        updateSway(t);
        updateText();
    }
    
    void updateCharacter()
    {
        playerWalking = false;
        const float speed = 4.0f;
        if (inputManager.getButton("left")) { character.move(camera.rightAbsolute, -speed); playerWalking = true; }
        if (inputManager.getButton("right")) { character.move(camera.rightAbsolute, speed); playerWalking = true; }
        if (inputManager.getButton("forward")) { character.move(camera.directionAbsolute, -speed); playerWalking = true; }
        if (inputManager.getButton("back")) { character.move(camera.directionAbsolute, speed); playerWalking = true; }
        if (inputManager.getButton("jump")) character.jump(2.0f);
        character.updateVelocity();
    }
    
    void updateWeaponMechanics(Time t)
    {
        const Vector3f targetPos = character.eyePoint - camera.directionAbsolute * 1.5f;
        if (cubeBody)
        {
            const Vector3f deltaPos = targetPos - cubeBody.position.xyz;
            const Vector3f velocity = deltaPos / t.delta * 0.3f;
            const Vector3f velocityDir = velocity.normalized;
            const float speed = velocity.length;
            if (speed > 10.0f)
                cubeBody.velocity = velocityDir * 10.0f;
            else
                cubeBody.velocity = velocity;
        }
    }
    
    void updateSway(Time t)
    {
        if (playerWalking && character.onGround)
        {
            camSwayTime += 7.0f * t.delta;
            gunSwayTime += 7.0f * t.delta;
        }
        else 
        {
            gunSwayTime += 1.0f * t.delta;
        }

        if (camSwayTime >= 2.0f * PI)
            camSwayTime = 0.0f;
        if (gunSwayTime >= 2.0f * PI)
            gunSwayTime = 0.0f;
        
        cameraPivot.position = character.eyePoint;
        Vector2f camSway = lissajousCurve(camSwayTime) / 15.0f;
        camera.position = Vector3f(camSway.x, camSway.y, 0.0f);

        /*
        Vector2f gunSway = lissajousCurve(gunSwayTime) / 15.0f;
        aGravitygun.entity.position = 
            Vector3f(0.15, -0.21, -0.2) + 
            Vector3f(gunSway.x * 0.1f, gunSway.y * 0.1f - fpview.pitch / 90.0f * 0.05f, 0.0f);
        aGravitygun.entity.rotation = rotationQuaternion!float(Axis.x, degtorad(fpview.pitch * 0.1f));
        */
    }
    
    char[100] txt;
    void updateText()
    {
        uint n = sprintf(txt.ptr, "FPS: %u", cast(int)(1.0 / eventManager.deltaTime));
        string s = cast(string)txt[0..n];
        text.setText(s);
    }
}

class TestGame: Game
{
    Soloud audio;
    
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        audio = Soloud.create();
        audio.init(Soloud.CLIP_ROUNDOFF | Soloud.LEFT_HANDED_3D);
        currentScene = New!GameplayScene(this, audio);
    }
    
    ~this()
    {
        audio.deinit();
    }
}

import loader = bindbc.loader.sharedlib;

void main(string[] args)
{
    NewtonSupport sup = loadNewton();
    foreach(info; loader.errors)
    {
        writeln(info.error.to!string, " ", info.message.to!string);
    }
    loadSoloud();

    TestGame game = New!TestGame(1600, 900, false, "eV [dev]", args);
    game.run();
    Delete(game);

    writeln("Allocated memory: ", allocatedMemory());
}
