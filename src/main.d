module main;

import std.stdio;
import std.conv;
import std.math;
import std.random;

import dagon;
import dagon.ext.ftfont;
import dagon.ext.newton;

Vector2f lissajousCurve(float t)
{
    return Vector2f(sin(t), cos(2 * t));
}

class TestScene: Scene, NewtonRaycaster
{
    Game game;
    FontAsset aFontDroidSans14;
    TextureAsset aEnvmap;
    OBJAsset aCubeMesh;
    TextureAsset aBoxDiffuse;
    TextureAsset aBoxNormal;
    TextureAsset aBoxRoughness;
    OBJAsset aLevel;
    ImageAsset aHeightmap;
    TextureAsset aGrass;
    TextureAsset aGrassNormal;
    PackageAsset aGravitygun;
    TextureAsset aTexColorTable;

    Entity cameraPivot;
    Camera camera;
    FirstPersonViewComponent fpview;

    TextureAsset aTexParticle;
    Entity eParticleSystem;
    Entity eParticlesGravity;
    Entity eParticlesGravityAttractor;
    Emitter emitterGravityDust;
    BlackHole attractorGravityDust;
    Light lightGravity;

    Light sun;
    Color4f sunColor = Color4f(1.0f, 0.7f, 0.5f, 1.0f);
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

    this(Game game)
    {
        super(game);
        this.game = game;
    }

    ~this()
    {
        if (cubeBodyControllers.length)
            Delete(cubeBodyControllers);
        if (sphereBodyControllers.length)
            Delete(sphereBodyControllers);
    }

    override void beforeLoad()
    {
        aFontDroidSans14 = this.addFontAsset("data/font/DroidSans.ttf", 14);
        aCubeMesh = addOBJAsset("data/box/box.obj");
        aBoxDiffuse = addTextureAsset("data/box/box-diffuse.png");
        aBoxNormal = addTextureAsset("data/box/box-normal.png");
        aBoxRoughness = addTextureAsset("data/box/box-roughness.png");
        
        aLevel = addOBJAsset("data/building/building.obj");
        aEnvmap = addTextureAsset("data/mars.png");
        aHeightmap = addImageAsset("data/terrain/heightmap.png");
        aGrass = addTextureAsset("data/terrain/dirt-albedo.png");
        aGrassNormal = addTextureAsset("data/terrain/dirt-normal.png");
        
        aGravitygun = addPackageAsset("data/gravitygun/gravitygun.asset");
        aTexParticle = addTextureAsset("data/particle.png");
        
        aTexColorTable = addTextureAsset("data/lut.png");
    }

    override void afterLoad()
    {
        world = New!NewtonPhysicsWorld(assetManager);

        world.loadPlugins("./");

        cameraPivot = addEntity();
        fpview = New!FirstPersonViewComponent(eventManager, cameraPivot);
        camera = addCamera(cameraPivot);
        game.renderer.activeCamera = camera;

        environment.backgroundColor = Color4f(0.9f, 0.8f, 1.0f, 1.0f);
        auto envCubemap = addCubemap(1024);
        envCubemap.fromEquirectangularMap(aEnvmap.texture);
        environment.ambientMap = envCubemap;
        environment.ambientEnergy = 0.3f;
        environment.fogColor = Color4f(0.651f, 0.553f, 0.6f, 1.0f);
        environment.fogEnd = 200.0f;

        game.deferredRenderer.ssaoEnabled = true;
        game.deferredRenderer.ssaoPower = 4.0f;
        game.deferredRenderer.ssaoRadius = 0.25f;
        game.deferredRenderer.ssaoDenoise = 1.0f;
        game.postProcessingRenderer.tonemapper = Tonemapper.Filmic;
        game.postProcessingRenderer.fxaaEnabled = true;
        game.postProcessingRenderer.motionBlurEnabled = true;
        game.postProcessingRenderer.glowEnabled = true;
        game.postProcessingRenderer.glowThreshold = 1.0f;
        game.postProcessingRenderer.glowIntensity = 0.3f;
        game.postProcessingRenderer.glowRadius = 7;
        game.postProcessingRenderer.lutEnabled = true;
        game.postProcessingRenderer.colorLookupTable = aTexColorTable.texture;
        game.postProcessingRenderer.lensDistortionEnabled = true;
        
        sun = addLight(LightType.Sun);
        sun.position.y = 50.0f;
        sun.shadowEnabled = true;
        sun.energy = 10.0f;
        sun.scatteringEnabled = true;
        sun.scattering = 0.35f;
        sun.mediumDensity = 0.1f;
        sun.scatteringUseShadow = false;
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
        eSky.material.culling = false;
        eSky.material.diffuse = envCubemap;
        
        auto box = New!NewtonBoxShape(Vector3f(0.625, 0.607, 0.65), world);
        auto boxMat = addMaterial();
        boxMat.diffuse = aBoxDiffuse.texture;
        boxMat.normal = aBoxNormal.texture;
        boxMat.roughness = aBoxRoughness.texture;

        cubeBodyControllers = New!(NewtonBodyComponent[])(numCubes);
        foreach(i; 0..cubeBodyControllers.length)
        {
            auto eCube = addEntity();
            eCube.drawable = aCubeMesh.mesh;
            eCube.material = boxMat;
            eCube.position = Vector3f(3, i * 1.5, 5);
            auto b = world.createDynamicBody(box, 80.0f);
            cubeBodyControllers[i] = New!NewtonBodyComponent(eventManager, eCube, b);
        }

        eCharacter = addEntity();
        eCharacter.position = Vector3f(0, 2, 20);
        character = New!NewtonCharacterComponent(eventManager, eCharacter, 1.8f, 80.0f, world);
        
        useEntity(aGravitygun.entity);
        aGravitygun.entity.setParent(camera);
        foreach(name, entityAsset; aGravitygun.entities)
        {
            auto entity = entityAsset.entity;
            entity.blurMask = 0.0f;
            useEntity(entity);
        }
        aGravitygun.entity.position = Vector3f(0.15, -0.2, -0.2);

        eParticleSystem = addEntity();
        auto particleSystem = New!ParticleSystem(eventManager, eParticleSystem);

        eParticlesGravity = addEntity();
        emitterGravityDust = New!Emitter(eParticlesGravity, particleSystem, 100);
        auto mParticlesDust = addMaterial();
        mParticlesDust.diffuse = aTexParticle.texture;
        mParticlesDust.emission = aTexParticle.texture;
        mParticlesDust.shadeless = true;
        mParticlesDust.blending = Transparent;
        mParticlesDust.depthWrite = false;
        mParticlesDust.energy = 10.0f;
        emitterGravityDust.material = mParticlesDust;
        emitterGravityDust.initialPositionRandomRadius = 2.0f;
        emitterGravityDust.minInitialSpeed = 0.01f;
        emitterGravityDust.maxInitialSpeed = 0.01f;
        emitterGravityDust.minSize = 0.005f;
        emitterGravityDust.maxSize = 0.01f;
        emitterGravityDust.startColor = Color4f(0.0f, 1.0f, 1.0f, 0.0f);
        emitterGravityDust.endColor = Color4f(0.0f, 1.0f, 1.0f, 0.25f);
        emitterGravityDust.minLifetime = 0.5f;
        emitterGravityDust.maxLifetime = 1.0f;
        emitterGravityDust.emitting = false;

        eParticlesGravityAttractor = addEntity();
        attractorGravityDust = New!BlackHole(eParticlesGravityAttractor, particleSystem, 3.0f);
        attractorGravityDust.active = false;

        lightGravity = addLight(LightType.Spot, aGravitygun.entity);
        lightGravity.position = Vector3f(0, 0, -0.3f);
        lightGravity.castShadow = false;
        lightGravity.color = Color4f(0.0f, 1.0f, 1.0f, 1.0f);
        lightGravity.energy = 10.0f;
        lightGravity.volumeRadius = 3.0f;
        lightGravity.specular = 0.0f;
        
        auto levelShape = New!NewtonMeshShape(aLevel.mesh, world);
        auto eLevel = addEntity();
        eLevel.drawable = aLevel.mesh;
        eLevel.turn(45);
        auto matLevel = New!Material(assetManager);
        matLevel.roughness = 0.3f;
        eLevel.material = matLevel;
        auto levelBody = world.createStaticBody(levelShape);
        auto levelBodyController = New!NewtonBodyComponent(eventManager, eLevel, levelBody);
        
        auto heightmap = New!ImageHeightmap(aHeightmap.image, 1.0f, assetManager);
        auto terrain = New!Terrain(128, 64, heightmap, assetManager);
        Vector3f terrainScale = Vector3f(1.0f, 5.0f, 1.0f);
        auto heightmapShape = New!NewtonHeightmapShape(heightmap, 128, 128, terrainScale, world);
        auto terrainBody = world.createStaticBody(heightmapShape);
        auto eTerrain = addEntity();
        eTerrain.position = Vector3f(-64, -4, -64);
        auto terrainBodyController = New!NewtonBodyComponent(eventManager, eTerrain, terrainBody);
        auto eTerrainVisual = addEntity(eTerrain);
        eTerrainVisual.dynamic = false;
        eTerrainVisual.solid = true;
        eTerrainVisual.material = addMaterial();
        eTerrainVisual.material.diffuse = aGrass.texture;
        eTerrainVisual.material.normal = aGrassNormal.texture;
        eTerrainVisual.material.textureScale = Vector2f(30, 30);
        eTerrainVisual.material.roughness = 0.8f;
        eTerrainVisual.drawable = terrain;
        eTerrainVisual.scaling = terrainScale;

        text = New!TextLine(aFontDroidSans14.font, "0", assetManager);
        text.color = Color4f(1.0f, 1.0f, 1.0f, 0.7f);
        auto eText = addEntityHUD();
        eText.drawable = text;
        eText.position = Vector3f(16.0f, 30.0f, 0.0f);
        
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
                oldDistance = float.max;
                world.raycast(character.eyePoint, character.eyePoint - camera.directionAbsolute * 30.0f, this);
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
                oldDistance = float.max;
                world.raycast(character.eyePoint, character.eyePoint - camera.directionAbsolute * 30.0f, this);
                if (cubeBody)
                {
                    Vector3f f = camera.directionAbsolute * -50000.0f;
                    cubeBody.addForce(f);
                    cubeBody = null;
                }
            }
        }
    }
    
    float oldDistance = float.max;
    float onRayHit(NewtonRigidBody nbody, Vector3f hitPoint, Vector3f hitNormal, float t)
    {
        if (!nbody.dynamic) return 1.0f;
        
        float d = distance(nbody.position.xyz, character.eyePoint);
        if (d < oldDistance)
        {
            oldDistance = d;
            cubeBody = nbody;
            return 1.0f;
        }
        else
        {
            return t;
        }
    }
    
    bool playerWalking = false;
    float camSwayTime = 0.0f;
    float gunSwayTime = 0.0f;
    
    override void onUpdate(Time t)
    {
        updateCharacter();
        
        const Vector3f targetPos = character.eyePoint - camera.directionAbsolute * 1.5f;
        if (cubeBody)
        {
            emitterGravityDust.emitting = true;
            attractorGravityDust.active = true;
            lightGravity.shining = true;

            const Vector3f deltaPos = targetPos - cubeBody.position.xyz;
            const Vector3f velocity = deltaPos / t.delta * 0.3f;
            const Vector3f velocityDir = velocity.normalized;
            const float speed = velocity.length;
            if (speed > 10.0f)
                cubeBody.velocity = velocityDir * 10.0f;
            else
                cubeBody.velocity = velocity;
            
            eParticlesGravity.position = cubeBody.position.xyz;
            eParticlesGravityAttractor.position = cubeBody.position.xyz;
        }
        else
        {
            emitterGravityDust.emitting = false;
            attractorGravityDust.active = false;
            lightGravity.shining = false;
        }
        
        world.update(t.delta);
        
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

        Vector2f gunSway = lissajousCurve(gunSwayTime) / 15.0f;
        aGravitygun.entity.position = 
            Vector3f(0.15, -0.2, -0.2) + 
            Vector3f(gunSway.x * 0.1f, gunSway.y * 0.1f - fpview.pitch / 90.0f * 0.05f, 0.0f);
        aGravitygun.entity.rotation = rotationQuaternion!float(Axis.x, degtorad(fpview.pitch * 0.1f));
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
        if (inputManager.getButton("jump")) character.jump(1.0f);
        character.updateVelocity();
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
    this(uint w, uint h, bool fullscreen, string title, string[] args)
    {
        super(w, h, fullscreen, title, args);
        currentScene = New!TestScene(this);
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

    TestGame game = New!TestGame(1600, 900, false, "Dagon + Newton Game Dynamics", args);
    game.run();
    //Delete(game);

    writeln("Allocated memory: ", allocatedMemory());
}
