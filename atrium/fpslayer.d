module atrium.fpslayer;

import std.math;
import std.random;

import derelict.opengl.gl;
import derelict.sdl.sdl;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.affine;
import dlib.geometry.triangle;
import dlib.image.color;
import dlib.image.io.png;

import dgl.core.drawable;
import dgl.core.layer;
import dgl.core.event;
import dgl.vfs.vfs;
import dgl.graphics.shapes;
import dgl.graphics.lamp;
import dgl.graphics.material;
import dgl.graphics.texture;
import dgl.vfs.vfs;
import dgl.asset.dgl;
import dgl.scene.scene;

import dmech.world;
import dmech.rigidbody;
import dmech.geometry;
import dmech.shape;
import dmech.constraint;
import dmech.bvh;
import dmech.contact;
import dmech.raycast;

import atrium.entity;
import atrium.fpcamera;
import atrium.cc;

class TeslaEffect: Drawable
{
    Vector3f[20] points;
    float length = 1.0f;
    Vector3f target = Vector3f(0, 0, 0);
    Matrix4x4f transformation;
    Weapon weapon;
    bool visible = false;
    float width = 1.0f;
    Vector3f start;
    Color4f color = Color4f(1, 1, 1, 1);
    Texture glowTex;
    
    this(Weapon weapon, Texture glowTex)
    {
        this.weapon = weapon;
        this.transformation = Matrix4x4f.identity;
        this.start = Vector3f(0,0,0);
        this.glowTex = glowTex;
        
        foreach(i, ref p; points)
            p = Vector3f(0, 0, -(cast(float)i)/(points.length-1));
    }
    
    float wildness = 0.1f;
    float vibrate = 0.0f;
    
    void calcPoints(uint left, uint right, float lh, float rh, uint comp)
    {
        float midh;
        uint mid;
        uint res;
        float fracScale;
        
        float random = uniform(0.0f, 1.0f);
        
        mid = (left + right) / 2;
        res = (left + right) % 2;
        fracScale = cast(float)(right - left) / points.length;
        midh = cast(float)(lh + rh) / 2.0f 
             + (fracScale * wildness * random) -
               (fracScale * wildness) / 2.0f;
               
        points[mid][comp] = midh + (vibrate * random - (vibrate / 2));
        
        if (res == 1)
            points[right - 1][comp] = points[right][comp];
        if ((mid - left) > 1)
            calcPoints(left, mid, lh, midh, comp);
        if ((right - mid) > 1)
            calcPoints(mid, right, midh, rh, comp);
    }
    
    override void draw(double dt)
    {
        if (!visible)
            return;

        calcPoints(0, points.length-1, 0, 0, 0);
        calcPoints(0, points.length-1, 0, 0, 1);
        
        transformation = 
              weapon.transformation 
            * translationMatrix(weapon.position + start);
            
        Vector3f currentDir = transformation.forward;
        Vector3f targetDir = (target - transformation.translation).normalized;
        auto rot = rotationBetweenVectors(-currentDir, targetDir);
        transformation *= rot;
        transformation *= scaleMatrix(Vector3f(length, length,length));
        
        glDisable(GL_LIGHTING);
        
        glPushMatrix();
        glMultMatrixf(transformation.arrayof.ptr);       
        // Draw lightning
        glLineWidth(width);
        glBegin(GL_LINE_STRIP);
        foreach(i, ref p; points)
        {
            glColor4f(color.r, color.g, color.b, (points.length - cast(float)i)/points.length);
            glVertex3fv(p.arrayof.ptr);
        }
        glEnd();
        glLineWidth(1.0f);
        glPopMatrix();

        // Draw glow
        glPushMatrix();
        glDepthMask(GL_FALSE);
        glowTex.bind(dt);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        float size = uniform(0.1f, 0.15f);
        Vector3f pt = Vector3f(0,0,0) * transformation;
        glColor4f(color.r, color.g, color.b, color.a);
        drawBillboard(pt, size);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glowTex.unbind();
        glDepthMask(GL_TRUE);
        glPopMatrix();
        
        glEnable(GL_LIGHTING);
    }
    
    void drawBillboard(Vector3f position, float scale)
    {
        Vector3f up = weapon.camera.transformation.up;
        Vector3f right = weapon.camera.transformation.right;
        Vector3f a = position - ((right + up) * scale);
        Vector3f b = position + ((right - up) * scale);
        Vector3f c = position + ((right + up) * scale);
        Vector3f d = position - ((right - up) * scale);
        
        glBegin(GL_QUADS);
        glTexCoord2i(0, 0); glVertex3fv(a.arrayof.ptr);
        glTexCoord2i(1, 0); glVertex3fv(b.arrayof.ptr);
        glTexCoord2i(1, 1); glVertex3fv(c.arrayof.ptr);
        glTexCoord2i(0, 1); glVertex3fv(d.arrayof.ptr);
        glEnd();
    }
    
    override void free() {}
}

// TODO: This function is total hack,
// need to rewrite BVH module to handle Triangle ranges,
// and add a method to Scene that will lazily return 
// transformed triangles for entities.
BVHTree!Triangle sceneBVH(Scene scene)
{
    Triangle[] tris;
    foreach(entity; scene.entities)
    {
        if (entity.type == 0)
        if (entity.meshId > -1)
        {
            Matrix4x4f mat = Matrix4x4f.identity;
            mat *= translationMatrix(entity.position);
            mat *= entity.rotation.toMatrix4x4;
            mat *= scaleMatrix(entity.scaling);

            auto mesh = scene.mesh(entity.meshId);
            foreach(fgroup; mesh.fgroups)
            foreach(tri; fgroup.tris)
            {
                Triangle tri2 = tri;
                tri2.v[0] = tri.v[0] * mat;
                tri2.v[1] = tri.v[1] * mat;
                tri2.v[2] = tri.v[2] * mat;
                tri2.normal = entity.rotation.rotate(tri.normal);
                tri2.barycenter = (tri2.v[0] + tri2.v[1] + tri2.v[2]) / 3;

                tris ~= tri2;
            }
        }
    }
    return new BVHTree!Triangle(tris, 4);
}

Vector2f lissajousCurve(float t)
{
    return Vector2f(sin(t), cos(2 * t));
}

class FPSLayer: Layer
{
    EventManager emanager;
    VirtualFileSystem vfs;
    
    enum double timeStep = 1.0 / 60.0;
    PhysicsWorld world;
    
    FirstPersonCamera camera;
    CharacterController ccPlayer;
    bool playerWalking = false;
    
    Weapon wGun;
    
    Scene scene;
    BVHTree!Triangle bvh;
    
    TeslaEffect tesla;
    //TeslaEffect tesla2;
    
    this(uint w, uint h, int depth, EventManager emanager)
    {
        super(0, 0, w, h, LayerType.Layer3D, depth);
        alignToWindow = true;
        
        this.emanager = emanager;
        
        // Create VFS
        this.vfs = new VirtualFileSystem();
        vfs.mount("data/levels/common");
        vfs.mount("data/levels/prism");
        vfs.mount("data/weapons");
        vfs.mount("data/items");
        
        // Create pysics world
        world = new PhysicsWorld(10000);
        
        // Create floor object
        auto geomFloorBox = new GeomBox(Vector3f(100, 1, 100));
        RigidBody bFloor = world.addStaticBody(Vector3f(0, -1, 0));
        world.addShapeComponent(bFloor, geomFloorBox, Vector3f(0, 0, 0), 1);
        
        // Create a single box
        // TODO: move to method
        auto scBox = loadScene(vfs.openForInput("box.dgl"), vfs);
        auto geomCube = new GeomBox(Vector3f(1, 1, 1));
        auto bodyCube = world.addDynamicBody(Vector3f(-5, 5, 0));
        bodyCube.bounce = 0.8f;
        world.addShapeComponent(bodyCube, geomCube, Vector3f(0, 0, 0), 40.0f);
        auto entCube = new DynamicEntity();
        entCube.drawable = scBox; //new ShapeBox(Vector3f(1, 1, 1));
        entCube.shape = bodyCube.shapes[0];
        addDrawable(entCube);
        
        // Create a pyramid of boxes
        buildPyramid(Vector3f(5, 0, 0), 4, 0, scBox);
        
        // Create lamp
        Lamp lamp = new Lamp(Vector4f(10.0f, 20.0f, 5.0f, 1.0f));
        addDrawable(lamp);
        
        // Create camera
        Vector3f playerPos = Vector3f(5, 3, 0);
        camera = new FirstPersonCamera(playerPos);
        camera.turn = -90.0f;
        camera.eyePosition = Vector3f(0, 1, 0);
        camera.gunPosition = Vector3f(0.15f, -0.2f, -0.2f);
        addModifier(camera);
        
        // Create character
        ccPlayer = new CharacterController(world, playerPos, 1.0f);
        ccPlayer.rotation.y = -90.0f;
        
        // Create gun
        auto w1sc = loadScene(vfs.openForInput("gravity-gun.dgl"), vfs);
        //auto drGun = new ShapeBox(Vector3f(0.05, 0.05, 0.2));
        wGun = new Weapon(camera, w1sc);
        //wGun.scale = Vector3f(0.5f, 0.5f, 0.5f);
        addDrawable(wGun);
        
        // Create scene
        auto istrm = vfs.openForInput("prism.dgl");
        scene = loadScene(istrm, vfs);
        addDrawable(scene);
        bvh = sceneBVH(scene);
        world.bvhRoot = bvh.root;
        
        auto glowTex = new Texture(loadPNG(vfs.openForInput("glow.png")));
        tesla = new TeslaEffect(wGun, glowTex);
        addDrawable(tesla);
        tesla.start = Vector3f(0, 0.1f, -0.5f);
        tesla.width = 3.0f;
        //auto rayColor = Color4f(0.5, 1, 0.5, 1); //Color4f(0.9f, 0.75f, 1, 1);
        tesla.color = Color4f(1.0f, 0.5f, 0.0f, 1.0f); //Color4f(0.9f, 0.75f, 1, 0.7); //Color4f(1, 0.5f, 0.5f, 1);
        /*
        tesla2 = new TeslaEffect(wGun, glowTex);
        addDrawable(tesla2);
        tesla2.start = Vector3f(-0.2f, 0.06f, -0.28f);
        tesla2.width = 1.0f;
        tesla2.color = Color4f(0.9f, 0.75f, 1, 0.7); // Color4f(0.5f, 0.5f, 1, 1);
        */
    }
    
    float gunSwayTime = 0.0f;
    
    double time = 0.0;
    override void onUpdate(EventManager emngr)
    {
        cameraControl();
    
        time += emngr.deltaTime;
        if (time >= timeStep)
        {
            time -= timeStep;
            playerControl();
            ccPlayer.update();
            world.update(timeStep);
        }
        
        camera.position = ccPlayer.rbody.position;
        swayControl();
    }
    
    void cameraControl()
    {
        SDL_ShowCursor(0);
        
        float turn_m = -(cast(float)(emanager.window_width/2 - emanager.mouse_x))/10.0f;
        float pitch_m = (cast(float)(emanager.window_height/2 - emanager.mouse_y))/10.0f;
        camera.pitch += pitch_m;
        camera.turn += turn_m;
        camera.gunPitch += pitch_m * 0.85f;
        SDL_WarpMouse(
            cast(ushort)emanager.window_width/2,
            cast(ushort)emanager.window_height/2);
    }
    
    void playerControl()
    {   
        playerWalking = false;
    
        Vector3f forward = camera.transformation.forward;
        Vector3f right = camera.transformation.right;
        
        ccPlayer.rotation.y = camera.turn;
        if (emanager.key_pressed['w']) { ccPlayer.move(forward, -8.0f); playerWalking = true; }
        if (emanager.key_pressed['s']) { ccPlayer.move(forward, 8.0f); playerWalking = true; }
        if (emanager.key_pressed['a']) { ccPlayer.move(right, -8.0f); playerWalking = true; }
        if (emanager.key_pressed['d']) { ccPlayer.move(right, 8.0f); playerWalking = true; }
        if (emanager.key_pressed[SDLK_SPACE]) ccPlayer.jump(3.0f);
        
        playerWalking = playerWalking && ccPlayer.onGround;
        
        shootWithGravityGun();
    }
    
    // TODO: move this behaviour to a class inheriting from Weapon
    RigidBody shootedBody = null;
    float attractDistance = 4.0f;
    bool canShoot = true;
    
    /*
override void onMouseButtonDown(EventManager manager)
{
if (manager.event_button == SDL_BUTTON_WHEELUP)
{
if (attractDistance < 20.0f)
attractDistance+=1;
}
else if (manager.event_button == SDL_BUTTON_WHEELDOWN)
{
if (attractDistance > 2.0f)
attractDistance-=1;
}
}
*/
    
    void shootWithGravityGun()
    {
        Vector3f camPos = camera.transformation.translation;
        Vector3f camDir = -camera.transformation.forward;
         CastResult cr;

        if (emanager.lmb_pressed)
        {
            if (canShoot)
            {
            canShoot = false;
            if (shootedBody is null)
            {
                if (world.raycast(camPos, camDir, 100.0f, cr, true, true))
                if (cr.rbody.dynamic)
                if (cr.rbody !is ccPlayer.rbody)
                {
                    shootedBody = cr.rbody;
                }
            }
            else
            {
                shootedBody.useGravity = true;
                shootedBody = null;
            }
            }
        }
        else
            canShoot = true;
            
        if (emanager.rmb_pressed)
        {
            if (shootedBody !is null)
            {
                shootedBody.useGravity = true;
                shootedBody.linearVelocity = camDir * 30.0f;
                shootedBody = null;
            }
        }
        
        tesla.visible = false;
        
        if (shootedBody)
        {
            Vector3f objPos = camPos + camDir * attractDistance;
        
            shootedBody.useGravity = false;
            auto b = shootedBody;
            Vector3f fvec = (objPos - b.position).normalized;
            float d = distance(objPos, b.position);
            
            if (d != 0.0f)
                b.linearVelocity = fvec * d * 5.0f;
                        
            float d1 = distance(tesla.transformation.translation, b.position);
            tesla.length = d1;
            tesla.visible = true;
            tesla.target = b.position;

               Vector3f objDir = (shootedBody.position - camPos).normalized;
                if (world.raycast(camPos, objDir, 100.0f, cr, true, true))
                if (cr.rbody !is ccPlayer.rbody)
                if (cr.rbody !is shootedBody)
                {
                    if (shootedBody)
                        shootedBody.useGravity = true;
                    shootedBody = null;
                }
        }
    }
   
    
    void swayControl()
    {
        if (playerWalking)
            gunSwayTime += 7.0f * emanager.deltaTime;
        else
            gunSwayTime += 1.0f * emanager.deltaTime;
        if (gunSwayTime > 2 * PI)
            gunSwayTime = 0.0f;
        Vector2f gunSway = lissajousCurve(gunSwayTime) / 10.0f;
        
        wGun.position = Vector3f(gunSway.x * 0.1f, gunSway.y * 0.1f, 0.0f);
        
        if (playerWalking)
        {
            camera.eyePosition = 
                Vector3f(0, 1, 0) + Vector3f(gunSway.x, 0.5f + gunSway.y, 0.0f);
            camera.roll = -gunSway.x * 5.0f;
        }
    }   
    
    void buildPyramid(Vector3f pyramidPosition, uint pyramidSize, uint pyramidGeom, Drawable drw)
    {
        float size = 0.5f;

        float cubeHeight = 1.0f;
/*
        auto box = new ShapeBox(Vector3f(size, cubeHeight * 0.5f, size));
        auto cyl = new ShapeCylinder(2.0f, 1.0f);
        auto con = new ShapeCone(2.0f, 1.0f);
        auto sph = new ShapeSphere(1.0f);
*/
        float width = size * 2.0f;
        float height = cubeHeight;
        float horizontal_spacing = 0.1f;
        float veritcal_spacing = 0.1f;

        auto geomBox = new GeomBox(Vector3f(size, cubeHeight * 0.5f, size));
        auto geomCylinder = new GeomCylinder(2.0f, 1.0f); 
        auto geomSphere = new GeomSphere(size); 
        auto geomCone = new GeomCone(2.0f, 1.0f); 

        foreach(i; 0..pyramidSize)
        foreach(e; i..pyramidSize)
        {
            auto position = pyramidPosition + Vector3f(
                (e - i * 0.5f) * (width + horizontal_spacing) - ((width + horizontal_spacing) * 5), 
                6.0f + (height + veritcal_spacing * 0.5f) + i * height + 0.26f,
                -3);

            Geometry g;
            //Drawable gobj;

            switch(pyramidGeom)
            {
                case 0:
                    g = geomBox;
                    //gobj = box;
                    break;
                case 1:
                    g = geomCylinder;
                    //gobj = cyl;
                    break;
                case 2:
                    g = geomSphere; 
                    //gobj = sph;
                    break;
                case 4:
                    g = geomCone;
                    //gobj = con;
                    break;
                default:
                    assert(0);
            }

            auto b = world.addDynamicBody(position, 0);
            world.addShapeComponent(b, g, Vector3f(0, 0, 0), 10);

            auto gameObj = new DynamicEntity();
            gameObj.drawable = drw; 
            gameObj.shape = b.shapes[0];

            Material mat = new Material();
            auto col = Color4f((randomUnitVector3!float + 0.5f).normalized);
            mat.ambientColor = col;
            mat.diffuseColor = col;
            gameObj.material = mat;
            
            gameObj.scale = Vector3f(size, size, size);

            addDrawable(gameObj);
        }
    }
}
