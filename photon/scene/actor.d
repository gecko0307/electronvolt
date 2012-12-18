module photon.scene.actor;

private
{
    import std.stdio;
    import std.path;
    import std.file;

    import derelict.opengl.gl;
    import derelict.opengl.glext;

    import dlib.math.vector;
    import dlib.math.matrix4x4;
    import dlib.math.quaternion;

    import photon.core.drawable;
    import photon.scene.scenenode;
    import photon.file.md5;

    import photon.geometry.bsphere;
}

// MD5ModelRead
// MD5AnimRead
// MD5ModelBuildBindPoseNormals
// MD5MeshPrepare
// MD5ArraysAlloc
// MD5ArraysFree
// MD5AnimIsValid
// MD5BuildFrameSkeleton
// MD5SkeletonsInterpolate
// MD5Animate

struct MD5AnimatedMesh
{
    MD5Model model;

    bool VBOSupported = false;
    bool VBOEnabled = true;

    GLuint VBOVertices;
    GLuint VBOIndices;

    //Texture[string] textures; 

    this(string meshFilename)
    {
        // Load mesh
        MD5ModelRead(meshFilename, model);
        MD5ModelBuildBindPoseNormals(model);

        // Init VBO
        VBOSupported = DerelictGL.isExtensionSupported("GL_ARB_vertex_buffer_object");

        if (VBOSupported && VBOEnabled)
        {
            glGenBuffersARB(1, &VBOVertices);
	    glGenBuffersARB(1, &VBOIndices);
        }

        // Load all necessary textures
        for (int i = 0; i < model.num_meshes; ++i)
        {
            string shaderPath = dirName(meshFilename) ~ "/" ~ model.meshes[i].shader;
            if (shaderPath.exists)
            {
                if (shaderPath.extension == ".png")
                {
                    //if (!(model.meshes[i].shader in textures)) {
                    //auto img = loadPNG(shaderPath);
                    //textures[model.meshes[i].shader] = new Texture(img); }
                }
            }
        }
    }

    void draw(MD5Skeleton skel = null)
    {
        glColor3f (1.0f, 1.0f, 1.0f);

        if (VBOSupported && VBOEnabled)
            drawWithVBO(skel);
        else
            drawWithVA(skel);
    }

    void drawWithVBO(MD5Skeleton skel = null)
    {
        for (int i = 0; i < model.num_meshes; ++i)
        {
            if (skel is null)
                MD5MeshPrepare(model.meshes[i], model.baseSkel);
            else
                MD5MeshPrepare(model.meshes[i], skel);

            //auto tex = model.meshes[i].shader in textures;
            //if (tex !is null) tex.bind();

            glBindBufferARB(GL_ARRAY_BUFFER_ARB, VBOVertices);

            int verticesSize  = float.sizeof * model.meshes[i].num_verts * 3;
            int normalsSize   = float.sizeof * model.meshes[i].num_verts * 3;
            int texcoordsSize = float.sizeof * model.meshes[i].num_verts * 2;
            int indicesSize   =   int.sizeof * model.meshes[i].num_tris  * 3;

            glBufferDataARB(   GL_ARRAY_BUFFER_ARB, verticesSize + normalsSize + texcoordsSize, cast(void*)0, GL_STATIC_DRAW_ARB);
            glBufferSubDataARB(GL_ARRAY_BUFFER_ARB, 0, verticesSize, md5StaticVertexArray.ptr);
            glBufferSubDataARB(GL_ARRAY_BUFFER_ARB, verticesSize, normalsSize, md5StaticNormalArray.ptr);
            glBufferSubDataARB(GL_ARRAY_BUFFER_ARB, verticesSize + normalsSize, texcoordsSize, md5StaticTexcoordArray.ptr);

            glClientActiveTextureARB(GL_TEXTURE0_ARB);
            glEnableClientState(GL_TEXTURE_COORD_ARRAY);
            glTexCoordPointer(2, GL_FLOAT, 0, cast(void*)(verticesSize + normalsSize));
            glEnableClientState(GL_NORMAL_ARRAY);
            glNormalPointer(GL_FLOAT, 0, cast(void*)verticesSize);
            glEnableClientState(GL_VERTEX_ARRAY);
            glVertexPointer(3, GL_FLOAT, 0, cast(void*)0);

            glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, VBOIndices);

            glBufferDataARB(GL_ELEMENT_ARRAY_BUFFER_ARB, indicesSize, md5StaticVertexIndicesArray.ptr, GL_STATIC_DRAW_ARB);
            glDrawElements(GL_TRIANGLES, model.meshes[i].num_tris * 3, GL_UNSIGNED_INT, cast(void*)0);

            glDisableClientState(GL_TEXTURE_COORD_ARRAY);
            glDisableClientState(GL_NORMAL_ARRAY);
            glDisableClientState(GL_VERTEX_ARRAY);

            glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);
            glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, 0);

            //if (tex !is null) tex.unbind();
        }
    }

    void drawWithVA(MD5Skeleton skel = null)
    {
        glEnableClientState(GL_VERTEX_ARRAY);
        glEnableClientState(GL_TEXTURE_COORD_ARRAY);
        glEnableClientState(GL_NORMAL_ARRAY);

        for (int i = 0; i < model.num_meshes; ++i)
        {
            if (skel is null)
                MD5MeshPrepare(model.meshes[i], model.baseSkel);
            else
                MD5MeshPrepare(model.meshes[i], skel);
                
            //auto tex = model.meshes[i].shader in textures;
            //if (tex !is null) tex.bind();

            glVertexPointer(3, GL_FLOAT, 0, md5StaticVertexArray.ptr);
            glTexCoordPointer(2, GL_FLOAT, 0, md5StaticTexcoordArray.ptr);
            glNormalPointer(GL_FLOAT, 0, md5StaticNormalArray.ptr);
            glDrawElements(GL_TRIANGLES, model.meshes[i].num_tris * 3, 
                           GL_UNSIGNED_INT, md5StaticVertexIndicesArray.ptr);
                               
            //if (tex !is null) tex.unbind();
        }

        glDisableClientState(GL_NORMAL_ARRAY);
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glDisableClientState(GL_VERTEX_ARRAY);
    }
}

struct MD5Animation
{
    MD5Anim anim;

    this(string animFilename)
    {
        MD5AnimRead(animFilename, anim);      
    }
}

final class MD5Actor: SceneNode
{
    MD5AnimatedMesh amesh;
    MD5Animation* animation = null;
    MD5Animation* animationNext = null;
    float smooth = 0.1f;

    MD5AnimInfo animInfo;

    MD5Skeleton currentSkeleton;

    float bsphereRadius;

    this(MD5AnimatedMesh animMesh, SceneNode par = null)
    {
        super(par);

        amesh = animMesh;

        animInfo.curr_frame = 0;
        animInfo.next_frame = 1;
        animInfo.last_time = 0;
        animInfo.max_time = 1.0 / 24;

        currentSkeleton = animMesh.model.baseSkel.dup;
    }

    void setAnimation(MD5Animation* anim)
    {
        animation = anim;
    }

    void smoothSwitchToAnimation(MD5Animation* anim, float sm = 0.1f)
    {
        animationNext = anim;
        smooth = sm;
        animInfo.last_time = 0;
    }

    void animate(double delta)
    {
        if (animation !is null) 
        {
            if (animationNext !is null)
            {
                animInfo.last_time += delta*smooth;
                MD5SkeletonsInterpolate(
                    animation.anim.skelFrames[animInfo.curr_frame],
                    animationNext.anim.skelFrames[0],
                    animation.anim.num_joints,
                    animInfo.last_time * animation.anim.frameRate,
                    currentSkeleton);

                if (animInfo.last_time >= animInfo.max_time)
                {
                    animation = animationNext;
                    animationNext = null;

                    animInfo.curr_frame = 0;
                    animInfo.next_frame = 1;
                    //animInfo.last_time = 0;
                    //animInfo.max_time = 1.0 / 24;
                }
            }
            else
            {
            MD5Animate(animation.anim, animInfo, delta);
            MD5SkeletonsInterpolate(
                animation.anim.skelFrames[animInfo.curr_frame],
                animation.anim.skelFrames[animInfo.next_frame],
                animation.anim.num_joints,
                animInfo.last_time * animation.anim.frameRate,
                currentSkeleton);
            }
        }
    }

    void render(double delta)
    {
        //glCullFace(GL_FRONT);
        if (animation is null)
            amesh.draw();
        else
        {
            animate(delta);
            amesh.draw(currentSkeleton);
        }
        //glCullFace(GL_BACK);
    }

    override @property BSphere boundingSphere()
    {
        return BSphere(position, bsphereRadius);
    }
}


