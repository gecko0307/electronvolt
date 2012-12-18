module photon.scene.particles;

private
{
    import std.math;
    import std.random;
    import derelict.opengl.gl;
    import dlib.math.vector;
    import dlib.math.matrix4x4;
    import dlib.image.color;
    import photon.scene.scenenode;
}

struct Particle
{
    float width = 1.0f;
    float height = 1.0f;
    
    Vector3f position;
    Vector3f direction;
    float speed = 25.0f;
    double life = 0.0;
    double maxLife = 1.0;
    
    ColorRGBAf color;
    
    bool alive = false;
    
    this(float w, float h)
    {
        width = w;
        height = h;
        position = Vector3f(0.0f, 0.0f, 0.0f);
        direction = Vector3f(0.0f, 1.0f, 0.0f);
    }
    
    void genColor()
    {
        color = ColorRGBAf(uniform(0.4f, 1.1f), 
                           uniform(0.4f, 1.1f), 
                           uniform(0.4f, 1.1f), 1.0f);
    }
    
    void draw(double delta)
    {
        if (alive)
        {
            glPushMatrix();

            Matrix4x4f modelViewMatrix;
            glGetFloatv(GL_MODELVIEW_MATRIX, modelViewMatrix.arrayof.ptr);

            glLoadIdentity();

            Vector3f transformedPos = position;
            modelViewMatrix.transform(transformedPos);

            glColor4f(color.r, color.g, color.b, color.a);
            glBegin(GL_TRIANGLE_STRIP);
            glVertex3f(transformedPos.x - width * 0.5f, transformedPos.y + height * 0.5f, transformedPos.z);
            glVertex3f(transformedPos.x - width * 0.5f, transformedPos.y - height * 0.5f, transformedPos.z);
            glVertex3f(transformedPos.x + width * 0.5f, transformedPos.y + height * 0.5f, transformedPos.z);
            glVertex3f(transformedPos.x + width * 0.5f, transformedPos.y - height * 0.5f, transformedPos.z);
            glEnd();

            glPopMatrix();
        
            position += direction * (speed * delta);
            life += delta;
            color.a = maxLife - life;
            if (life >= maxLife)
            {
                life = 0.0;
                position = Vector3f(0.0f, 0.0f, 0.0f);
                alive = false;
            }
        }
    }
}

final class ParticleEmitter: SceneNode
{
    private:
    uint particleCount;
    Particle[] particles;
    double delayCtr = 0.0;
    double delay = 0.01;

    public:
    float directionRandomFactor = 1.0f;
    
    public:
    this(uint pcount = 10000, SceneNode par = null)
    {
        super(par);
        particleCount = pcount;
        particles = new Particle[particleCount];
        particles[] = Particle(0.25f, 0.25f);
        foreach(ref p; particles)
            p.genColor();
    }

    invariant()
    {
        assert(0.0f <= directionRandomFactor && directionRandomFactor <= 1.0f);
    }
       
    override void render(double delta)
    {
        glPushAttrib(GL_ENABLE_BIT); 
        glDisable(GL_LIGHTING);
        
        delayCtr += delta;
        if (delayCtr >= delay)
        {
            int pind = getFirstDead();
            if (pind >= 0)
            {
                particles[pind].alive = true;
                particles[pind].direction = 
                    localMatrix.forward * (1.0f-directionRandomFactor) + 
                    randomUnitVector3!float() * directionRandomFactor;
            }
            delayCtr = 0.0;
        }
        
        foreach(ref p; particles)
        {
            p.draw(delta);
        }
        glPopAttrib();
    }

    private int getFirstDead()
    {
        foreach(i, ref p; particles)
        {
            if (!p.alive) 
                return i;
        }
        return -1;
    }
}


