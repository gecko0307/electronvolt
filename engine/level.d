module engine.level;

import std.math;
import std.conv;

import derelict.sdl.sdl;
import derelict.opengl.gl;

import dlib.math.vector;
import dlib.math.matrix4x4;
import dlib.geometry.triangle;
import dlib.geometry.ray;
import dlib.image.io.png;

import engine.logic;
import engine.ui.text;
import engine.scene.bvh;
import engine.scene.scenenode;
import engine.scene.primitives;
import engine.scene.tbcamera;
import engine.dat;
import engine.fgroup;
import engine.menu;
import engine.pause;
import engine.graphics.texture;

import engine.physics.constants;
import engine.physics.contact;
import engine.physics.geometry;
import engine.physics.integrator;
import engine.physics.rigidbody;
import engine.physics.solver;
import engine.physics.world;

Vector2f lissajousCurve(float t)
{
    return Vector2f(sin(t), cos(2 * t));
}

    void drawQuad(float width, float height)
    {
        glBegin(GL_QUADS);
        glTexCoord2f(0,1); glVertex2f(-width*0.5f, -height*0.5f); 
        glTexCoord2f(0,0); glVertex2f(-width*0.5f, +height*0.5f);
        glTexCoord2f(1,0); glVertex2f(+width*0.5f, +height*0.5f);
        glTexCoord2f(1,1); glVertex2f(+width*0.5f, -height*0.5f);
        glEnd();
    }

final class Weapon: SceneNode
{
    DatObject datobj;
    FaceGroup[int] fgroups;
    
    this(string filename, SceneNode par = null)
    {
        super(par);
        datobj = new DatObject(filename);
        fgroups = createFGroups(datobj);
    }
    
    override void render(double delta)
    {
        foreach(fgroup; fgroups)
            glCallList(fgroup.displayList);
    }
}

class LevelObject: GameObject
{
    DatObject levelData;
    BVHTree levelBVH;

    // triangle groups by material index
    FaceGroup[int] levelFGroups;

    PhysicsWorld world;

    SceneNode scene;

    GeomSphere playerGeometry;
    SceneNode player;
    SceneNode cameraPivot;
    SceneNode camera;
    enum playerGrav = 0.2f;
    bool jumped = false;
    bool playerWalking = false;

    //TrackballCamera tbcamera;
    //int tempMouseX = 0;
    //int tempMouseY = 0;

    SceneNode gravityGunPivot;
    Weapon gravityGun;
    float gunSwayTime = 0.0f;

    RigidBody shootedBody = null;

    Vector4f lightPos = Vector4f(0.0f, 40.0f, 0.0f, 1.0f);

    Text txtFPS;

    Texture crosshair;

    this(string datFilename, GameLogicManager m)
    {
        super(m);

        txtFPS = new Text(logic.fontMain);
        txtFPS.setPos(16, 16);

        levelData = new DatObject(datFilename);
        levelBVH = new BVHTree(levelData.tris, 1);
        levelFGroups = createFGroups(levelData);

        scene = new SceneNode();

        world = new PhysicsWorld(PhysicalEnvironment.Earth);

        RigidBody playerBody = world.addDynamicRigidBody(80.0f);
        playerGeometry = new GeomSphere(0.5f);
        playerBody.setGeometry(playerGeometry);
        playerBody.disableRotation = true;
        playerBody.position = Vector3f(0.0f, 10.0f, 0.0f);
        playerBody.dampingFactor = 0.7f;
        playerBody.gravityDirection = Vector3f(0.0f, -playerGrav, 0.0f);

        player = new SceneNode(scene);
        player.rigidBody = playerBody;

        cameraPivot = new SceneNode(player);

        camera = new SceneNode(cameraPivot);
        camera.position = Vector3f(0.0f, 0.5f, 0.0f);

        player.rigidBody.position = levelData.spawnPosition;

        gravityGunPivot = new SceneNode(scene);
        gravityGun = new Weapon("data/weapons/gravitygun/gravitygun.dat", gravityGunPivot);

        foreach(orb; levelData.orbs)
        {
            RigidBody rb = world.addDynamicRigidBody(10.0f);
            rb.setGeometry(new GeomSphere(0.25f));
            rb.position = orb.position;
            PrimSphere prim = new PrimSphere(0.25f, 18, 10, scene);
            //prim.setMaterial(mWhite);
            prim.rigidBody = rb;
        }

        world.bvhRoot = levelBVH.root;

        //tbcamera = new TrackballCamera();

        crosshair = new Texture(loadPNG("data/weapons/crosshair.png"), false);

        SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                      cast(ushort)manager.window_height/2);
    }

    override void onKeyDown()
    {
        if (manager.event_key == SDLK_ESCAPE)
        {
            // TODO: pauseMenu
            //(cast(MainMenuRoom)(logic.rooms["mainMenu"])).objects[0].resumeEntry.enabled = true;
            //logic.gameIsPaused = true;
            logic.goToRoom("pauseMenu", false, false);
        }
    }

    override void onMouseButtonDown()
    {
/*
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
            tbcamera.zoomSmooth(-2.0f, 16.0f);
        }
        else if (manager.event_button == SDL_BUTTON_WHEELDOWN) 
        {
            tbcamera.zoomSmooth(2.0f, 16.0f);
        }
*/
    }

    void drawFGroups(FaceGroup[int] fgroups)
    {
        foreach(fgroup; fgroups)
            glCallList(fgroup.displayList);
    }

    override void onDraw(double delta)
    {
        SDL_ShowCursor(0);
/*
        // Camera control
        if (manager.rmb_pressed)
        {
            float turn_m = (cast(float)(manager.window_width/2 - manager.mouse_x))/8.0f;
            float pitch_m = -(cast(float)(manager.window_height/2 - manager.mouse_y))/8.0f;
            tbcamera.pitchSmooth(pitch_m, 16.0f);
            tbcamera.turnSmooth(turn_m, 16.0f);
            SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                          cast(ushort)manager.window_height/2);
        }

        if (manager.mmb_pressed || (manager.lmb_pressed && manager.key_pressed[SDLK_LSHIFT]))
        {
            float shift_x = (cast(float)(manager.window_width/2 - manager.mouse_x))/16.0f;
            float shift_y = (cast(float)(manager.window_height/2 - manager.mouse_y))/16.0f;
            tbcamera.moveSmooth(shift_y, 16.0f);
            tbcamera.strafeSmooth(-shift_x, 16.0f);
            SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                          cast(ushort)manager.window_height/2);
        }
*/

        // Camera control        
        float turn_m =   (cast(float)(manager.window_width/2 - manager.mouse_x))/10.0f;
        float pitch_m = -(cast(float)(manager.window_height/2 - manager.mouse_y))/10.0f;
        
        //rotationX += pitch_m; 
        camera.rotation.x += pitch_m;
        //rotationY += turn_m; 
        cameraPivot.rotation.y += turn_m;
        SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                      cast(ushort)manager.window_height/2);

        // Vertical collision detection
        float floorHeight = 0.0f;
        float ceilHeight = float.max;

        Ray downRay;
        downRay.p0 = player.rigidBody.position;
        downRay.p1 = Vector3f(
            player.rigidBody.position.x, 
           -10.0f,
            player.rigidBody.position.z);

        // Look down
        levelBVH.root.traverseByRay(downRay, (ref Triangle tri)
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
                    //groundNormal = tri.normal;
                    float s = dot(Vector3f(0.0f, 1.0f, 0.0f), tri.normal);
                    if (s > 0.5f) // Hit a slope
                        player.rigidBody.gravityDirection = -tri.normal * playerGrav;
                }
            }
        });

        // Player movement
        playerWalking = false; 
        if (manager.key_pressed['w'])
        {
            player.rigidBody.applyForce(-cameraPivot.absoluteMatrix.forward * 600.0f);
            //camSwingTime += 8.0f * manager.deltaTime;
            if (player.rigidBody.lastGroundContact.fact)
                playerWalking = true;
        }

        if (manager.key_pressed['s'])
        {
            player.rigidBody.applyForce(cameraPivot.absoluteMatrix.forward * 600.0f);
            //camSwingTime += 8.0f * manager.deltaTime;
            if (player.rigidBody.lastGroundContact.fact)
                playerWalking = true;
        }

        if (manager.key_pressed['a'])
        {
            player.rigidBody.applyForce(-cameraPivot.absoluteMatrix.right * 600.0f);
            //camSwingTime += 8.0f * manager.deltaTime;
            if (player.rigidBody.lastGroundContact.fact)
                playerWalking = true;
        }

        if (manager.key_pressed['d'])
        {
            player.rigidBody.applyForce(cameraPivot.absoluteMatrix.right * 600.0f);
            //camSwingTime += 8.0f * manager.deltaTime;
            if (player.rigidBody.lastGroundContact.fact)
                playerWalking = true;
        }

        if (manager.key_pressed[SDLK_SPACE])
        {
            if (!jumped)
            {
                if (player.rigidBody.lastGroundContact.fact)
                {
                    player.rigidBody.applyForce(player.localMatrix.up * 200.0f);
                    player.rigidBody.lastGroundContact.fact = false;
                    jumped = true;
                }
            }
        }
        else jumped = false;

        // Shoot
        shootWithGravityRay(600.0f);

        // Update physics
        world.clearContacts();
        world.process2(manager.deltaTime);

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glLoadIdentity();

        Matrix4x4f camMatrixInv = camera.absoluteMatrix.inverse;
        glPushMatrix();
        glMultMatrixf(camMatrixInv.arrayof.ptr);
        //tbcamera.bind(delta);

        glLightfv(GL_LIGHT0, GL_POSITION, lightPos.arrayof.ptr);

        drawFGroups(levelFGroups);

        Matrix4x4f camMatrix = camera.absoluteMatrix;
        camMatrix *= translationMatrix(Vector3f(0.08f, -0.1f, -0.2f));
        camMatrix *= scaleMatrix(Vector3f(0.05f, 0.05f, 0.05f));
        gravityGunPivot.localMatrixPtr = &camMatrix;
        
        if (playerWalking)
            gunSwayTime += 10.0f * manager.deltaTime; //0.1f
        else
            gunSwayTime += 1.0f * manager.deltaTime; //0.01f
            
        if (gunSwayTime > 2 * PI)
            gunSwayTime = 0.0f;
        Vector2f gunSway = lissajousCurve(gunSwayTime) / 10.0f;
        
        gravityGun.position = Vector3f(gunSway.x, gunSway.y, 0.0f);
        if (playerWalking)
            camera.position = Vector3f(gunSway.x, 0.5f + gunSway.y, 0.0f);

        scene.draw(delta);

        glPopMatrix();
        //tbcamera.unbind();

        // 2D mode
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        glOrtho(0, manager.window_width, 0, manager.window_height, -1, 1);
        glMatrixMode(GL_MODELVIEW);

        glLoadIdentity();

        glDisable(GL_LIGHTING);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);

        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
        
        glPushMatrix();
        glTranslatef(manager.window_width/2, manager.window_height/2, 0);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);
        crosshair.bind(delta);
        drawQuad(32, 32);
        crosshair.unbind();
        glEnable(GL_CULL_FACE);
        glEnable(GL_DEPTH_TEST);
        glPopMatrix();

        txtFPS.render(to!dstring(manager.fps));

        glEnable(GL_CULL_FACE);
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_LIGHTING);

        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);
    }

    void shootWithGravityRay(float energy)
    {
        Vector3f forwardVec = camera.absoluteMatrix.forward;
        Vector3f camPos = camera.absoluteMatrix.translation - forwardVec * 1.5f;
            Ray shootRay = Ray(
                camera.absoluteMatrix.translation, 
                camera.absoluteMatrix.translation - forwardVec * 1000.0f);
        float minDistance = float.max;
        if (manager.lmb_pressed)
        {
            if (shootedBody is null)
            foreach(b; world.rigidBodies)
            {
                if (b !is player.rigidBody)
                if (b.dynamic && b.geometry.type == GeometryType.Sphere)
                {
                    Vector3f ip;
                    if (shootRay.intersectSphere(b.position, (cast(GeomSphere)b.geometry).radius, ip))
                    {
                        float d = distance(camPos, b.position);
                        if (d < minDistance)
                        {
                            shootedBody = b;
                            minDistance = d;
                        }
                    }
                }
            }
        }
        else 
        {
            if (shootedBody)
            {
                shootedBody.gravityEnabled = true;
                
                //float d = distance(camPos, shootedBody.position);
                //float forceMag = 0.85f * (1.0f/d);
                //Vector3f fvec = -forwardVec * forceMag;
                //shootedBody.applyForce(fvec);
            }

            shootedBody = null;
        }

        if (shootedBody)
        {
            auto b = shootedBody;
            b.gravityEnabled = false;

            Vector3f fvec = (camPos - b.position).normalized;

            float d = distance(camPos, b.position);
            float bspeed = b.linearVelocity.length;
            float forceMag = energy * (1.0f/d);

            float spd = forceMag/b.mass + bspeed;
            if (d != 0.0f)
            {
                if (d >= spd)
                    b.linearVelocity = fvec * spd;
                else
                    b.linearVelocity = fvec * d;
            }
        }
    }
}

class LevelRoom: GameRoom
{
    string datfile;

    this(string datFilename, GameLogicManager m)
    {
        super(m);
        datfile = datFilename;
    }

    override void onLoad()
    {
        glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
        glEnable(GL_LIGHTING);
        glEnable(GL_LIGHT0);

        addObject(new LevelObject(datfile, logic));
    }
}

