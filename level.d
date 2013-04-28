module level;

private
{
    import std.math;
    import std.conv;

    import derelict.sdl.sdl;
    import derelict.opengl.gl;
    import derelict.opengl.glext;

    import dlib.math.vector;
    import dlib.math.matrix4x4;
    import dlib.math.utils;

    import dlib.geometry.triangle;
    import dlib.geometry.trimesh;
    import dlib.geometry.ray;
    
    import dlib.image.io.png;

    import atrium.all;

    import utils;
    import dat;
}

class FaceGroup
{
    Triangle[] tris;
    uint displayList;
    int materialIndex;
}

FaceGroup[int] createFGroups(DatObject datobj)
{
    FaceGroup[int] fgroups;
    
    foreach(tri; datobj.tris)
    {
        int m = tri.materialIndex;
          
        if (!(m in fgroups))
        {
            fgroups[m] = new FaceGroup();
            fgroups[m].materialIndex = m;
        }
                
        fgroups[m].tris ~= tri;
    }
        
    foreach(fgroup; fgroups)
    {
        fgroup.displayList = glGenLists(1);
        glNewList(fgroup.displayList, GL_COMPILE);
            
        Material* mat = fgroup.materialIndex in datobj.materialByIndex;
           
        if (mat !is null)
            mat.bind(0.0);
         
        foreach(tri; fgroup.tris)
        {               
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
        }
            
        if (mat !is null)
            mat.unbind();
            
        glEndList();
    }
    
    return fgroups;
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

final class Level
{
    AppManager manager;

    DatObject levelData;
    BVHTree levelBVH;

    PhysicsWorld world;

    SceneNode scene;

    GeomSphere playerGeometry;
    SceneNode player;
    SceneNode cameraPivot;
    SceneNode camera;
    enum playerGrav = 0.2f;
    bool jumped = false;
    bool playerWalking = false;
    
    SceneNode gravityGunPivot;
    Weapon gravityGun;
    
    float gunSwayTime = 0.0f;

    Frustum frst;

    // triangle groups by material index
    FaceGroup[int] levelFGroups;

    RigidBody shootedBody = null;

    Vector4f lightPos = Vector4f(0.0f, 40.0f, 0.0f, 1.0f);
    
    //TODO: don't store font here
    Font ftMain;
    
    Text txtFPS;
    
    Texture crosshair;
    
    float rotationX = 0.0f;
    float rotationY = 0.0f;

    this(string datFilename, AppManager appManager)
    {
        manager = appManager;
        
        // Create font and text
        ftMain = new Font();
        ftMain.init("data/fonts/droid/DroidSans.ttf", 14);

        txtFPS = new Text(ftMain);
        txtFPS.setPos(16, 16);

        levelData = new DatObject(datFilename);
        levelBVH = new BVHTree(levelData.tris, 1);

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
        //cameraPivot.rotation = levelData.spawnRotation;
        
        gravityGunPivot = new SceneNode(scene);
        gravityGun = new Weapon("data/weapon/gravitygun.dat", gravityGunPivot);
        //gravityGun.scaling = Vector3f(0.05f, 0.05f, 0.05f);
        //gravityGun.position = Vector3f(0.08f, -0.1f, -0.2f);
        
        crosshair = new Texture(loadPNG("data/weapon/crosshair.png"), false);

        foreach(orb; levelData.orbs)
        {
            RigidBody rb = world.addDynamicRigidBody(10.0f);
            rb.setGeometry(new GeomSphere(0.25f));
            rb.position = orb.position;
            PrimSphere prim = new PrimSphere(0.25f, 18, 10, scene);
            //prim.setMaterial(mWhite);
            prim.rigidBody = rb;
        }
/*
        levelBVH.root.traverse((BVHNode node)
        {
            node.userData = glGenLists(1);
            glNewList(node.userData, GL_COMPILE);
            foreach(tri; node.tris)
            {
                Material* mat = tri.materialIndex in levelData.materialByIndex;
                
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

        levelFGroups = createFGroups(levelData);
        //gravityGunFGroups = createFGroups(gravityGunData);

        world.bvhRoot = levelBVH.root;

        SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                      cast(ushort)manager.window_height/2);
    }

    void drawFGroups(FaceGroup[int] fgroups)
    {
    /*
        if (frst.containsAABB(node.aabb) || 
            frst.intersectsAABB(node.aabb))
        {
            if (node.child[0] !is null)
                drawGeometryCulled(node.child[0], frst);
            if (node.child[1] !is null)
                drawGeometryCulled(node.child[1], frst);

            if (node.userData)
            {
                glCallList(node.userData);
            }
        }
    */
        foreach(fgroup; fgroups)
            glCallList(fgroup.displayList);
    }

    void run()
    {
        // Camera control        
        float turn_m =   (cast(float)(manager.window_width/2 - manager.mouse_x))/10.0f;
        float pitch_m = -(cast(float)(manager.window_height/2 - manager.mouse_y))/10.0f;
        
        rotationX += pitch_m; camera.rotation.x += pitch_m;
        rotationY += turn_m; cameraPivot.rotation.y += turn_m;
        SDL_WarpMouse(cast(ushort)manager.window_width/2, 
                      cast(ushort)manager.window_height/2);

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
        world.process(manager.deltaTime);
        //player.rigidBody.angularVelocity = Vector3f(0.0f, 0.0f, 0.0f);

        // Draw everything
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glLoadIdentity();

        Matrix4x4f camMatrixInv = camera.absoluteMatrix.inverse;
        glPushMatrix();
        glMultMatrixf(camMatrixInv.arrayof.ptr);

        glLightfv(GL_LIGHT0, GL_POSITION, lightPos.arrayof.ptr);

        //frst.setFromMVP(getMVPMatrix());
        drawFGroups(levelFGroups);
        
        Matrix4x4f camMatrix = camera.absoluteMatrix;
        camMatrix *= translationMatrix(Vector3f(0.08f, -0.1f, -0.2f));
        camMatrix *= scaleMatrix(Vector3f(0.05f, 0.05f, 0.05f));
        gravityGunPivot.localMatrixPtr = &camMatrix;
        
        if (playerWalking)
            gunSwayTime += 0.1f;
        else
            gunSwayTime += 0.01f;
            
        if (gunSwayTime > 2 * PI)
            gunSwayTime = 0.0f;
        Vector2f gunSway = lissajousCurve(gunSwayTime) / 10.0f;
        
        gravityGun.position = Vector3f(gunSway.x, gunSway.y, 0.0f);
        if (playerWalking)
            camera.position = Vector3f(gunSway.x, 0.5f + gunSway.y, 0.0f);

        scene.draw(manager.deltaTime);
        
        Matrix4x4f rayStartMatrix = camera.absoluteMatrix;
        rayStartMatrix *= translationMatrix(Vector3f(0.08f, -0.1f, -0.5f));
        Vector3f rayStart = rayStartMatrix.translation;
        
        if (shootedBody)
        {
            glDisable(GL_LIGHTING);
            glColor3f(1.0f, 0.0f, 0.0f);
            glLineWidth(5.0f);
            glBegin(GL_LINE_STRIP);
            glVertex3fv(rayStart.arrayof.ptr);
            glVertex3fv(shootedBody.position.arrayof.ptr);
            glEnd();
            glLineWidth(1.0f);
            glEnable(GL_LIGHTING);
        }

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
        
        glPushMatrix();
        glTranslatef(manager.window_width/2, manager.window_height/2, 0);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_CULL_FACE);
        crosshair.bind(manager.deltaTime);
        drawQuad(32, 32);
        crosshair.unbind();
        glEnable(GL_CULL_FACE);
        glEnable(GL_DEPTH_TEST);
        glPopMatrix();
        
        txtFPS.render(to!dstring(manager.fps));

        glEnable(GL_LIGHTING);

        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);
    }
    
    Vector2f lissajousCurve(float t)
    {
        return Vector2f(sin(t), cos(2 * t));
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
                //Vector3f fvec = -forwardVec * 1000.0f * attenuation(d, 1.0f, 0.0f, 0.0f);
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
    
    void drawQuad(float width, float height)
    {
        glBegin(GL_QUADS);
        glTexCoord2f(0,1); glVertex2f(-width*0.5f, -height*0.5f); 
        glTexCoord2f(0,0); glVertex2f(-width*0.5f, +height*0.5f);
        glTexCoord2f(1,0); glVertex2f(+width*0.5f, +height*0.5f);
        glTexCoord2f(1,1); glVertex2f(+width*0.5f, -height*0.5f);
        glEnd();
    }
}

