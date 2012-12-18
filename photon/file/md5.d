module photon.file.md5;

private
{
    import std.c.stdlib;
    import std.c.stdio;
    import std.c.string;

    import std.stdio;
    import std.string;
    import std.conv;
    import std.math;

    import dlib.math.vector;
    import dlib.math.quaternion;
}

// Joint
struct MD5Joint
{
    char[64] name;
    int parent;

    Vector3f pos;
    Quaternionf orient;
}

// Vertex
struct MD5Vertex
{
    Vector3f bindpos;
    Vector2f st;
    Vector3f normal;

    int start; // start weight
    int count; // weight count
}

// Triangle
struct MD5Triangle
{
    int[3] index;
}

// Weight
struct MD5Weight
{
    int joint;
    float bias;

    Vector3f pos;
}

// Bounding box
struct MD5BBox
{
    Vector3f min;
    Vector3f max;
}

// MD5 mesh
struct MD5Mesh
{
    MD5Vertex[] vertices;
    MD5Triangle[] triangles;
    MD5Weight[] weights;

    int num_verts;
    int num_tris;
    int num_weights;

    //char[256] shader = 0;
    string shader;
}

alias MD5Joint[] MD5Skeleton;

// MD5 model structure
struct MD5Model
{
    MD5Skeleton baseSkel;
    MD5Mesh[] meshes;

    int num_joints;
    int num_meshes;
}

// Animation data
struct MD5Anim
{
    int num_frames;
    int num_joints;
    int frameRate;

    MD5Skeleton[] skelFrames;
    MD5BBox[] bboxes;
}

// Animation info
struct MD5AnimInfo
{
    int curr_frame;
    int next_frame;

    double last_time;
    double max_time;
}

// Joint info
struct MD5JointInfo
{
    char[64] name = 0;
    int parent;
    int flags;
    int startIndex;
}

// Base frame joint
struct MD5BaseFrameJoint
{
    Vector3f pos;
    Quaternionf orient;
}

// vertex array related stuff
int max_verts = 0;
int max_tris = 0;

static Vector3f[] md5StaticVertexArray;
static uint[] md5StaticVertexIndicesArray;
static Vector2f[] md5StaticTexcoordArray;
static Vector3f[] md5StaticNormalArray;

// uncomment this to see debug messages:
//version = md5_debug;

/*
 * Load an MD5 model from file.
 */
bool MD5ModelRead(string filename, ref MD5Model mdl)
{
    char[512] buff;
    int md5_version;
    int curr_mesh = 0;
    int i, j;

    FILE *fp;
    fp = fopen (toStringz(filename), "rb");

    if (!fp)
    {
        writefln("md5 error: couldn't open \"%s\"!", filename);
        return false;
    }

    while (!feof(fp))
    {
        // Read whole line
        fgets (buff.ptr, buff.length, fp);

        if (sscanf(buff.ptr, " MD5Version %d", &md5_version) == 1)
        {
            version(md5_debug) writefln("md5 debug: md5_version = %s", md5_version);

            if (md5_version != 10)
            {
                // Bad version
                writeln("md5 error: bad model version");
                fclose (fp);
                return false;
            }
        }
        else if (sscanf(buff.ptr, " numJoints %d", &mdl.num_joints) == 1)
        {
            version(md5_debug) writefln("md5 debug: mdl.num_joints = %s", mdl.num_joints);

            if (mdl.num_joints > 0)
            {
                // Allocate memory for base skeleton joints
                mdl.baseSkel = new MD5Joint[mdl.num_joints];
            }
        }
        else if (sscanf(buff.ptr, " numMeshes %d", &mdl.num_meshes) == 1)
        {
            version(md5_debug) writefln("md5 debug: mdl.num_meshes = %s", mdl.num_meshes);

            if (mdl.num_meshes > 0)
            {
                // Allocate memory for meshes
                mdl.meshes = new MD5Mesh[mdl.num_meshes];
            }
        }
        else if (strncmp(buff.ptr, toStringz("joints {"), 8) == 0)
        {
            // Read each joint
            for (i = 0; i < mdl.num_joints; ++i)
            {
                MD5Joint* joint = &mdl.baseSkel[i];

                // Read whole line
                fgets(buff.ptr, buff.length, fp);

                if (sscanf(buff.ptr, "%s %d ( %f %f %f ) ( %f %f %f )",
                           joint.name.ptr, &joint.parent, 
                          &joint.pos.arrayof[0], &joint.pos.arrayof[1], &joint.pos.arrayof[2], 
                          &joint.orient.arrayof[0], &joint.orient.arrayof[1], &joint.orient.arrayof[2]) == 8)
                {
                    // Compute the w component
                    joint.orient.computeW();

                    version(md5_debug) writefln("md5 debug: mdl.baseSkel[%s].pos = %s", i, joint.pos);
                    version(md5_debug) writefln("md5 debug: mdl.baseSkel[%s].orient = %s", i, joint.orient);
                }
            }
        }
        else if (strncmp(buff.ptr, toStringz("mesh {"), 6) == 0)
        {
            MD5Mesh* mesh = &mdl.meshes[curr_mesh];

            int vert_index = 0;
            int tri_index = 0;
            int weight_index = 0;
            float[4] fdata;
            int[3] idata;

            while ((buff[0] != '}') && !feof(fp))
            {
                // Read whole line
                fgets(buff.ptr, buff.length, fp);

                if (strstr (buff.ptr, toStringz("shader ")))
                {
                    char[256] temp_shader = 0;

                    int quote = 0; 
                    j = 0;

                    // Copy the shader name whithout the quote marks
                    for (i = 0; i < buff.length && (quote < 2); ++i)
                    {
                        if (buff[i] == '\"')
                        quote++;

                        if ((quote == 1) && (buff[i] != '\"'))
                        {
                            temp_shader[j] = buff[i];
                            j++;
                        }
                    }

                    mesh.shader = to!string(temp_shader.ptr);

                    version(md5_debug) writefln("md5 debug: mdl.meshes[%s].shader = %s", curr_mesh, to!string(mesh.shader));
                }
                else if (sscanf(buff.ptr, " numverts %d", &mesh.num_verts) == 1)
                {
                    if (mesh.num_verts > 0)
                    {
                        // Allocate memory for vertices
                        mesh.vertices = new MD5Vertex[mesh.num_verts];
                    }

                    if (mesh.num_verts > max_verts)
                        max_verts = mesh.num_verts;

                    version(md5_debug) writefln("md5 debug: mdl.meshes[%s].num_verts = %s", curr_mesh, mesh.num_verts);
                }
                else if (sscanf(buff.ptr, " numtris %d", &mesh.num_tris) == 1)
                {
                    if (mesh.num_tris > 0)
                    {
                        // Allocate memory for triangles
                        mesh.triangles = new MD5Triangle[mesh.num_tris];
                    }

                    if (mesh.num_tris > max_tris)
                        max_tris = mesh.num_tris;

                    version(md5_debug) writefln("md5 debug: mdl.meshes[%s].num_tris = %s", curr_mesh, mesh.num_tris);
                }
                else if (sscanf(buff.ptr, " numweights %d", &mesh.num_weights) == 1)
                {
                    if (mesh.num_weights > 0)
                    {
                        // Allocate memory for vertex weights
                        mesh.weights = new MD5Weight[mesh.num_weights];
                    }

                    version(md5_debug) writefln("md5 debug: mdl.meshes[%s].num_weights = %s", curr_mesh, mesh.num_weights);
                }
                else if (sscanf(buff.ptr, " vert %d ( %f %f ) %d %d", 
                                &vert_index, &fdata[0], &fdata[1], &idata[0], &idata[1]) == 5)
                {
                    // Copy vertex data
                    mesh.vertices[vert_index].st.arrayof[] = fdata[0..2];
                    mesh.vertices[vert_index].start = idata[0];
                    mesh.vertices[vert_index].count = idata[1];

                    version(md5_debug) 
                    {
                        writefln("md5 debug: mdl.meshes[%s].vertices[%s].st = %s", curr_mesh, vert_index, mesh.vertices[vert_index].st);
                        writefln("md5 debug: mdl.meshes[%s].vertices[%s].start = %s", curr_mesh, vert_index, mesh.vertices[vert_index].start);
                        writefln("md5 debug: mdl.meshes[%s].vertices[%s].count = %s", curr_mesh, vert_index, mesh.vertices[vert_index].count);
                    }
                }
                else if (sscanf(buff.ptr, " tri %d %d %d %d", 
                                &tri_index, &idata[0], &idata[1], &idata[2]) == 4)
                {
                    // Copy triangle data
                    mesh.triangles[tri_index].index[0] = idata[0];
                    mesh.triangles[tri_index].index[1] = idata[1];
                    mesh.triangles[tri_index].index[2] = idata[2];

                    version(md5_debug) writefln("md5 debug: mdl.meshes[%s].triangles[%s].index = %s", curr_mesh, tri_index, idata);
                }
                else if (sscanf(buff.ptr, " weight %d %d %f ( %f %f %f )",
                    &weight_index, 
                                &idata[0], &fdata[3], &fdata[0], &fdata[1], &fdata[2]) == 6)
                {
                    // Copy weight data
                    mesh.weights[weight_index].joint  = idata[0];
                    mesh.weights[weight_index].bias   = fdata[3];
                    mesh.weights[weight_index].pos[0] = fdata[0];
                    mesh.weights[weight_index].pos[1] = fdata[1];
                    mesh.weights[weight_index].pos[2] = fdata[2];

                    version(md5_debug) 
                    {
                        writefln("md5 debug: mdl.meshes[%s].weights[%s].joint = %s", curr_mesh, weight_index, idata[0]);
                        writefln("md5 debug: mdl.meshes[%s].weights[%s].bias = %s", curr_mesh, weight_index, fdata[3]);
                        writefln("md5 debug: mdl.meshes[%s].weights[%s].pos = %s", curr_mesh, weight_index, fdata[0..3]);
                    }
                }
            }

            curr_mesh++;
        }
    }

    fclose (fp);

    return true;
}

void MD5MeshBuildBindPoseVertices(ref MD5Model mdl)
{
    // warning: no sanity check for model!
    auto skeleton = mdl.baseSkel;

    int m, i, j;

    for (m = 0; m < mdl.num_meshes; ++m)
    {
        MD5Mesh *mesh = &mdl.meshes[m];

        // Setup vertices
        for (i = 0; i < mesh.num_verts; ++i)
        {
            Vector3f finalVertex = Vector3f(0.0f, 0.0f, 0.0f);

            // Calculate final vertex to draw with weights
            for (j = 0; j < mesh.vertices[i].count; ++j)
            {
                MD5Weight* weight = &mesh.weights[mesh.vertices[i].start + j];
                MD5Joint* joint = &skeleton[weight.joint];

                // Calculate transformed vertex for this weight
                Vector3f wv = weight.pos;
                joint.orient.rotate(wv);

                // The sum of all weight.bias should be 1.0
                finalVertex += (joint.pos + wv) * weight.bias;
            }

            mesh.vertices[i].bindpos = finalVertex;
        }
    }
}

void MD5ModelBuildBindPoseNormals(ref MD5Model mdl)
{
    if (mdl.baseSkel && mdl.meshes)
    {
        MD5MeshBuildBindPoseVertices(mdl);

        for (int i = 0; i < mdl.num_meshes; ++i)
        {
            if (mdl.meshes[i].vertices)
            for (int j = 0; j < mdl.meshes[i].num_verts; j++)
            {
                mdl.meshes[i].vertices[j].normal = Vector3f(0.0f, 0.0f, 0.0f);
            }

            if (mdl.meshes[i].triangles)
            for (int j = 0; j < mdl.meshes[i].num_tris; j++)
            {
                MD5Vertex* v0 = &mdl.meshes[i].vertices[ mdl.meshes[i].triangles[j].index[0] ];
                MD5Vertex* v1 = &mdl.meshes[i].vertices[ mdl.meshes[i].triangles[j].index[1] ];
                MD5Vertex* v2 = &mdl.meshes[i].vertices[ mdl.meshes[i].triangles[j].index[2] ];

                Vector3f A = v1.bindpos - v0.bindpos;
                Vector3f B = v2.bindpos - v0.bindpos;

                Vector3f n = cross(A, B);
                //n.y = -n.y;

                v0.normal += n;
                v1.normal += n;
                v2.normal += n;
            }

            if (mdl.meshes[i].vertices)
            for (int j = 0; j < mdl.meshes[i].num_verts; j++)
            {
                MD5Vertex* v = &mdl.meshes[i].vertices[j];
                v.normal.normalize();
                //v.normal = -v.normal;
            }
        }
    }
}

/*
 * Prepare a mesh for drawing.
 * Compute mesh's final vertex positions given a skeleton.
 * Put the vertices in vertex arrays.
 */
void MD5MeshPrepare(ref MD5Mesh mesh, MD5Joint[] skeleton)
{
    int i, j, k;

    // Setup vertex indices
    for (k = 0, i = 0; i < mesh.num_tris; ++i)
    {
        for (j = 0; j < 3; j++, k++)
        md5StaticVertexIndicesArray[k] = mesh.triangles[i].index[j];
    }
    // Setup vertices
    for (i = 0; i < mesh.num_verts; ++i)
    {
        Vector3f finalVertex = Vector3f(0.0f, 0.0f, 0.0f);

        // Calculate final vertex to draw with weights
        for (j = 0; j < mesh.vertices[i].count; ++j)
        {
            MD5Weight* weight = &mesh.weights[mesh.vertices[i].start + j];
            MD5Joint* joint = &skeleton[weight.joint];
            // Calculate transformed vertex for this weight
            Vector3f wv = weight.pos;
            joint.orient.rotate(wv);

            // The sum of all weight->bias should be 1.0
            finalVertex += (joint.pos + wv) * weight.bias;
        }

        md5StaticVertexArray[i] = finalVertex;
        md5StaticTexcoordArray[i] = mesh.vertices[i].st;
        md5StaticNormalArray[i] = mesh.vertices[i].normal;
    }
}

void MD5ArraysAlloc()
{
    md5StaticVertexArray = new Vector3f[max_verts];
    md5StaticVertexIndicesArray = new uint[max_tris * 3];
    md5StaticTexcoordArray = new Vector2f[max_verts];
    md5StaticNormalArray = new Vector3f[max_verts];
}

void MD5ArraysFree()
{
    delete md5StaticVertexArray;
    delete md5StaticVertexIndicesArray;
    delete md5StaticTexcoordArray;
    delete md5StaticNormalArray;
}

/*
 * Check if an animation can be used for a given model.
 * Model's skeleton and animation's skeleton must match.
 */
bool MD5AnimIsValid(ref MD5Model mdl, ref MD5Anim anim)
{
    int i;

    // md5mesh and md5anim must have the same number of joints
    if (mdl.num_joints != anim.num_joints)
        return false;

    // We just check with frame[0]
    for (i = 0; i < mdl.num_joints; ++i)
    {
        // Joints must have the same parent index
        if (mdl.baseSkel[i].parent != anim.skelFrames[0][i].parent)
        return false;

        // Joints must have the same name
        if (strcmp(mdl.baseSkel[i].name.ptr, anim.skelFrames[0][i].name.ptr) != 0)
        return false;
    }

    return true;
}

/*
 * Build skeleton for a given frame data.
 */
void MD5BuildFrameSkeleton(MD5JointInfo[] jointInfos, 
                           MD5BaseFrameJoint[] baseFrame, 
                           float[] animFrameData, 
                           MD5Joint[] skelFrame,
                           int num_joints)
{
    int i;

    for (i = 0; i < num_joints; ++i)
    {
        MD5BaseFrameJoint* baseJoint = &baseFrame[i];

        int j = 0;

        Vector3f animatedPos = baseJoint.pos;
        Quaternionf animatedOrient = baseJoint.orient;

        if (jointInfos[i].flags & 1) // Tx
        {
            animatedPos.x = animFrameData[jointInfos[i].startIndex + j];
            ++j;
        }

        if (jointInfos[i].flags & 2) // Ty
        {
            animatedPos.y = animFrameData[jointInfos[i].startIndex + j];
            ++j;
        }

        if (jointInfos[i].flags & 4) // Tz
        {
            animatedPos.z = animFrameData[jointInfos[i].startIndex + j];
            ++j;
        }

        if (jointInfos[i].flags & 8) // Qx
        {
            animatedOrient.x = animFrameData[jointInfos[i].startIndex + j];
            ++j;
        }

        if (jointInfos[i].flags & 16) // Qy
        {
            animatedOrient[1] = animFrameData[jointInfos[i].startIndex + j];
            ++j;
        }

        if (jointInfos[i].flags & 32) // Qz
        {
            animatedOrient[2] = animFrameData[jointInfos[i].startIndex + j];
            ++j;
        }

        // Compute orient quaternion's w value
        animatedOrient.computeW();

        // NOTE: we assume that this joint's parent has
        // already been calculated, i.e. joint's ID should
        // never be smaller than its parent ID.
        MD5Joint* thisJoint = &skelFrame[i];

        int parent = jointInfos[i].parent;
        thisJoint.parent = parent;
        strcpy(thisJoint.name.ptr, jointInfos[i].name.ptr);

        // Has parent?
        if (thisJoint.parent < 0)
        {
            thisJoint.pos = animatedPos;
            thisJoint.orient = animatedOrient;
        }
        else
        {
            MD5Joint* parentJoint = &skelFrame[parent];
            Vector3f rpos = animatedPos; // Rotated position
            parentJoint.orient.rotate(rpos);

            // Add positions
            thisJoint.pos = rpos + parentJoint.pos;

            // Concatenate rotations
            thisJoint.orient = parentJoint.orient * animatedOrient;
            thisJoint.orient.normalize();
        }
    }
}

/*
 * Load an MD5 animation from file.
 */
bool MD5AnimRead(string filename, ref MD5Anim anim)
{
    FILE* fp = null;
    char[512] buff;
    MD5JointInfo[] jointInfos;
    MD5BaseFrameJoint[] baseFrame;
    float[] animFrameData;
    int md5_version;
    int numAnimatedComponents;
    int frame_index;
    int i;

    fp = fopen(toStringz(filename), "rb");

    if (!fp)
    {
        writeln("md5 error: couldn't open \"%s\"!", filename);
        return false;
    }

    while (!feof(fp))
    {
        // Read whole line
        fgets (buff.ptr, buff.length, fp);

        if (sscanf(buff.ptr, " MD5Version %d", &md5_version) == 1)
        {
            version(md5_debug) writefln("md5 debug: md5_version = %s", md5_version);

            if (md5_version != 10)
            {
                // Bad version
                writeln("md5 error: bad model version");
                fclose (fp);
                return false;
            }
        }
        else if (sscanf(buff.ptr, " numFrames %d", &anim.num_frames) == 1)
        {
            version(md5_debug) writefln("md5 debug: anim.num_frames = %s", anim.num_frames);

            // Allocate memory for skeleton frames and bounding boxes
            if (anim.num_frames > 0)
            {
                anim.skelFrames = new MD5Skeleton[anim.num_frames];
                anim.bboxes = new MD5BBox[anim.num_frames];
            }
        }
        else if (sscanf(buff.ptr, " numJoints %d", &anim.num_joints) == 1)
        {
            version(md5_debug) writefln("md5 debug: anim.num_joints = %s", anim.num_joints);

            if (anim.num_joints > 0)
            {
                for (i = 0; i < anim.num_frames; ++i)
                {
                    // Allocate memory for joints of each frame
                    anim.skelFrames[i] = new MD5Joint[anim.num_joints];
                }
                
                jointInfos = new MD5JointInfo[anim.num_joints];
                baseFrame = new MD5BaseFrameJoint[anim.num_joints];
            }
        }
        else if (sscanf(buff.ptr, " frameRate %d", &anim.frameRate) == 1)
        {
            version(md5_debug) writefln("md5 debug: anim.frameRate = %s", anim.frameRate);
        }
        else if (sscanf(buff.ptr, " numAnimatedComponents %d", &numAnimatedComponents) == 1)
        {
            version(md5_debug) writefln("md5 debug: numAnimatedComponents = %s", numAnimatedComponents);

            if (numAnimatedComponents > 0)
            {
                // Allocate memory for animation frame data
	        animFrameData = new float[numAnimatedComponents];
	    }
	}
        else if (strncmp(buff.ptr, "hierarchy {", 11) == 0)
        {
            for (i = 0; i < anim.num_joints; ++i)
            {
                // Read whole line
                fgets(buff.ptr, buff.length, fp);

                // Read joint info
                sscanf(buff.ptr, " %s %d %d %d", jointInfos[i].name.ptr, &jointInfos[i].parent,
                       &jointInfos[i].flags, &jointInfos[i].startIndex);

                version(md5_debug)
                {
                    writefln("md5 debug: jointInfos[%s].name = %s", i, to!string(jointInfos[i].name));
                    writefln("md5 debug: jointInfos[%s].parent = %s", i, jointInfos[i].parent);
                    writefln("md5 debug: jointInfos[%s].flags = %s", i, jointInfos[i].flags);
                    writefln("md5 debug: jointInfos[%s].startIndex = %s", i, jointInfos[i].startIndex);
                }
	    }
	}
        else if (strncmp(buff.ptr, "bounds {", 8) == 0)
        {
            for (i = 0; i < anim.num_frames; ++i)
            {
                // Read whole line
                fgets(buff.ptr, buff.length, fp);

                // Read bounding box

                sscanf(buff.ptr, " ( %f %f %f ) ( %f %f %f )",
                       &anim.bboxes[i].min.arrayof[0], 
                       &anim.bboxes[i].min.arrayof[1],
                       &anim.bboxes[i].min.arrayof[2], 
                       &anim.bboxes[i].max.arrayof[0],
                       &anim.bboxes[i].max.arrayof[1], 
                       &anim.bboxes[i].max.arrayof[2]);

                version(md5_debug)
                {
                    writefln("md5 debug: anim.bboxes[%s].min = %s", i, anim.bboxes[i].min);
                    writefln("md5 debug: anim.bboxes[%s].max = %s", i, anim.bboxes[i].max);
                }
            }
        }
        else if (strncmp(buff.ptr, "baseframe {", 10) == 0)
        {
            for (i = 0; i < anim.num_joints; ++i)
            {
                // Read whole line
                fgets(buff.ptr, buff.length, fp);

                // Read base frame joint
                if (sscanf(buff.ptr, " ( %f %f %f ) ( %f %f %f )",
                           &baseFrame[i].pos.arrayof[0], 
                           &baseFrame[i].pos.arrayof[1], 
                           &baseFrame[i].pos.arrayof[2], 
                           &baseFrame[i].orient.arrayof[0], 
                           &baseFrame[i].orient.arrayof[1], 
                           &baseFrame[i].orient.arrayof[2]) == 6)
                {
                    // Compute the w component
                    baseFrame[i].orient.computeW();

                    version(md5_debug)
                    {
                        writefln("md5 debug: baseFrame[%s].pos = %s", i, baseFrame[i].pos);
                        writefln("md5 debug: baseFrame[%s].orient = %s", i, baseFrame[i].orient);
                    }
		}
	    }
	}
        else if (sscanf(buff.ptr, " frame %d", &frame_index) == 1)
        {
            // Read frame data
            for (i = 0; i < numAnimatedComponents; ++i)
                fscanf(fp, "%f", &animFrameData[i]);

            // Build frame skeleton from the collected data
            MD5BuildFrameSkeleton(jointInfos, baseFrame, animFrameData, anim.skelFrames[frame_index], anim.num_joints);
	}
    }

    fclose(fp);

    // Free temporary data allocated
    if (animFrameData) 
        delete animFrameData;

    if (baseFrame)
        delete baseFrame;

    if (jointInfos)
        delete jointInfos;

    return true;
}

/*
 * Smoothly interpolate two skeletons
 */
void MD5SkeletonsInterpolate(MD5Skeleton skelA, MD5Skeleton skelB, int num_joints, float interp, MD5Skeleton skelOut)
{
    for (int i = 0; i < num_joints; ++i)
    {
        // Copy parent index
        skelOut[i].parent = skelA[i].parent;

        // Linear interpolation for position
        skelOut[i].pos = skelA[i].pos + interp * (skelB[i].pos - skelA[i].pos);

        // Spherical linear interpolation for orientation
        skelOut[i].orient = slerp(skelA[i].orient, skelB[i].orient, interp);
    }
}

/*
 * Perform animation related computations. 
 * Calculate the current and next frames, given a delta time.
 */
void MD5Animate(ref MD5Anim anim, ref MD5AnimInfo animInfo, double dt)
{
    int maxFrames = anim.num_frames - 1;

    animInfo.last_time += dt;

    // move to next frame
    if (animInfo.last_time >= animInfo.max_time)
    {
        animInfo.curr_frame++;
        animInfo.next_frame++;
        animInfo.last_time = 0.0;

        if (animInfo.curr_frame > maxFrames)
	    animInfo.curr_frame = 0;

        if (animInfo.next_frame > maxFrames)
	    animInfo.next_frame = 0;
    }
}



