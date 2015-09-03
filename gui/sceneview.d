module gui.sceneview;

import std.stdio;
import std.math;
import dlib;
import dgl;
import gui.widget;
import gui.scene;
import gui.window;

class SceneView: Widget
{
    Color4f backgroundColor;
    bool alignToWindow = true;
    TrackballCamera camera;
    DynamicArray!Drawable drawables;
    EditorScene scene;
    bool grabMouse = false;
    bool active = false;
    Vector4f lightPosition;
    float aspectRatio;
    float fovY = 60;
    float maxPickDistance = 1000.0f;
        
    this(EventManager emngr, Widget parentWidget)
    {
        super(emngr, parentWidget);
        backgroundColor = Color4f(0.4, 0.4, 0.4, 1);
        
        camera = New!TrackballCamera();
        camera.pitch(45.0f);
        camera.turn(45.0f);
        camera.setZoom(20.0f);
        
        lightPosition = Vector4f(1, 1, 0.5, 0);
    }
    
    bool mouseInsideWindow()
    {
        Window parent = cast(Window)parentWidget;
        if (parent)
        {
        if (parent.minimized)
            return false;
        else
            return mouseInArea(parent.position + Vector2f(0.0f, parent.titlebarHeight), parent.scale);
        }
        else
            return parentWidget.mouseOver();
    }
    
    override bool mouseOver()
    {
        return parentWidget.mouseOver();
    }
    
    void addDrawable(Drawable d)
    {
        drawables.append(d);
    }
    
    ~this()
    {
        camera.free();
        foreach(d; drawables.data)
            d.free();
        drawables.free();
    }
    
    override void free()
    {
        Delete(this);
    }
    
    override void onClick(int button)
    {
        grabMouse = true;
        active = true;
    }
    
    override void onUpdate()
    {
        scene.gizmo.processEvents();
        scene.onUpdate();
        processEvents();
    }
    
    void updateSelectedEntity()
    {
        if (scene.gizmo.entity)
            scene.gizmo.applyTranformationTo(scene.gizmo.entity);
    }
    
    void selectEntity(Entity e)
    {
        scene.gizmo.entity = e;
        scene.gizmo.position = e.position;
    }
    
    void unselectEntity()
    {
        transform = false;
        scene.gizmo.highlightedAxis = 0;
        scene.gizmo.entity = null;
    }
    
    Vector3f cameraPoint(float x, float y, float dist)
    {        
        return camera.getPosition() + cameraDir(x, y) * dist;
    }
        
    Vector3f cameraMousePoint(float x, float y, float dist)
    {
        Vector2f absPos = parentWidget.sourcePoint() + position;
        return cameraPoint(x - absPos.x, (eventManager.windowHeight - y) - absPos.y, dist);
    }
    
    Vector3f cameraDir(float x, float y)
    {
        Vector3f camDir = -camera.getDirectionVector();

        float fovX = fovXfromY(fovY, aspectRatio);

        float tfov1 = tan(fovY*PI/360.0f);
        float tfov2 = tan(fovX*PI/360.0f);
        
        Vector3f camUp = camera.getUpVector() * tfov1;
        Vector3f camRight = -camera.getRightVector() * tfov2;

        float width  = 1.0f - 2.0f * x / scale.x;
        float height = 1.0f - 2.0f * y / scale.y;
        
        Vector3f m = camDir + camUp * height + camRight * width;
        Vector3f dir = m.normalized;
        
        return dir;
    }
    
    Ray cameraRay(float x, float y)
    {
        Vector3f camPos = camera.getPosition();
        Ray r = Ray(camPos, camPos + cameraDir(x, y) * maxPickDistance);
        return r;
    }
    
    Vector3f mouseDir()
    {
        Vector2f absPos = parentWidget.sourcePoint() + position;
        return cameraDir(eventManager.mouseX - absPos.x, (eventManager.windowHeight - eventManager.mouseY) - absPos.y);
    }
    
    Ray mouseRay()
    {
        Vector2f absPos = parentWidget.sourcePoint() + position;
        return cameraRay(eventManager.mouseX - absPos.x, (eventManager.windowHeight - eventManager.mouseY) - absPos.y);
    }
    
    Ray mouseRay(float x, float y)
    {
        Vector2f absPos = parentWidget.sourcePoint() + position;
        return cameraRay(x - absPos.x, (eventManager.windowHeight - y) - absPos.y);
    }
    
    bool transform = false;
    Vector3f transformAxis;
    Vector3f initialTrans;
    
    Vector3f rayPlaneIsec(Ray r, Vector3f axis)
    {
        Plane p;
        Vector3f rayNormal = (r.p1 - r.p0).normalized;
        p.fromPointAndNormal(scene.gizmo.position, rayNormal);
        Vector3f ip;
        if (p.intersectsLineSegment(r.p0, r.p1, ip))
            return ip;
        else return Vector3f(0, 0, 0);
    }
    
    override void onMouseButtonDown(int button)
    {
        if ((button == SDL_BUTTON_LEFT || button == SDL_BUTTON_RIGHT)
             && !mouseOver)
            active = false;
    
        if (active && mouseInsideWindow)
        {
            if (button == SDL_BUTTON_LEFT)
            {
                scene.gizmo.ray = mouseRay();
                Entity picked = pickEntity(scene.gizmo.ray);
                
                if (scene.gizmo.entity)
                {
                    Vector3f axis, ip;
                    if (scene.gizmo.pickAxis(scene.gizmo.ray, axis, ip))
                    {
                        prevMouseX = eventManager.mouseX;
                        prevMouseY = eventManager.mouseY;
                        transformAxis = axis;
                        initialTrans = rayPlaneIsec(scene.gizmo.ray, Vector3f(0, 1, 0)) - scene.gizmo.position;
                        transform = true;
                        if (axis.x) scene.gizmo.highlightedAxis = 1;
                        else if (axis.y) scene.gizmo.highlightedAxis = 2;
                        else if (axis.z) scene.gizmo.highlightedAxis = 3;
                    }
                    else if (picked)
                    {
                        unselectEntity();
                        scene.gizmo.entity = picked;
                    }
                    else
                    {
                        unselectEntity();
                    }
                }
                else if (picked)
                {
                    scene.gizmo.entity = picked;
                }
                else
                {
                    unselectEntity();
                }
            }
            else if (button == SDL_BUTTON_MIDDLE)
            {
                prevMouseX = eventManager.mouseX;
                prevMouseY = eventManager.mouseY;
            }
        }
        
        if (active && mouseInsideWindow)
        {
            if (button == SDL_BUTTON_WHEELUP)
            {
                camera.zoom(1.0f);
            }
            else if (button == SDL_BUTTON_WHEELDOWN)
            {
                camera.zoom(-1.0f);
            }
        }

        if (!mouseOver)
            grabMouse = false;
    }
    
    Entity pickEntity(Ray r)
    {
        Entity res = null;
    
        if (scene)
        {
            float min_t = float.max;
            foreach(e; scene.entities.data)
            {
                AABB aabb = e.getAABB();
                float t;
                if (aabb.intersectsSegment(scene.gizmo.ray.p0, scene.gizmo.ray.p1, t))
                {
                    if (t < min_t)
                    {
                        min_t = t;
                        res = e;
                    }
                }
            }
        }
        
        return res;
    }

    override void onMouseButtonUp(int button)
    {
        transform = false;
        scene.gizmo.highlightedAxis = 0;
    }
    
    int prevMouseX;
    int prevMouseY;
    override void draw(double dt)
    {
        if (grabMouse)
        {
            if (eventManager.mouseButtonPressed[SDL_BUTTON_LEFT] && transform)
            {
                Vector3f p0 = rayPlaneIsec(mouseRay(prevMouseX, prevMouseY), Vector3f(0, 1, 0));
                Vector3f p1 = rayPlaneIsec(mouseRay(), Vector3f(0, 1, 0));
                Vector3f trans = p1 - scene.gizmo.position - initialTrans;
                trans *= transformAxis;
                scene.gizmo.translate(trans);
                updateSelectedEntity();
            }
            else if (eventManager.mouseButtonPressed[SDL_BUTTON_MIDDLE] && eventManager.keyPressed[SDLK_LSHIFT])
            {
                float shift_x = (eventManager.mouseX - prevMouseX) * 0.1f;
                float shift_y = (eventManager.mouseY - prevMouseY) * 0.1f;
                Vector3f trans = camera.getUpVector * shift_y + camera.getRightVector * shift_x;
                camera.translateTarget(trans);
            }
            else if (eventManager.mouseButtonPressed[SDL_BUTTON_MIDDLE] && eventManager.keyPressed[SDLK_LCTRL])
            {
                float shift_x = (eventManager.mouseX - prevMouseX);
                float shift_y = (eventManager.mouseY - prevMouseY);
                camera.zoom((shift_x + shift_y) * 0.1f);
            }
            else if (eventManager.mouseButtonPressed[SDL_BUTTON_MIDDLE])
            {                
                float turn_m = (eventManager.mouseX - prevMouseX);
                float pitch_m = -(eventManager.mouseY - prevMouseY);
                camera.pitch(pitch_m);
                camera.turn(turn_m);
            }
                
            prevMouseX = eventManager.mouseX;
            prevMouseY = eventManager.mouseY;
        }
        
        GLint[4] viewport;
        glGetIntegerv(GL_VIEWPORT, viewport.ptr);
        
        if (alignToWindow)
        {
            scale = parentWidget.scale;
            position = Vector2f(0, 0);
        }
        
        Vector2f absPos = parentWidget.sourcePoint() + position + Vector2f(0.0f, scale.y);
        glViewport(cast(uint)absPos.x, cast(uint)(eventManager.windowHeight - absPos.y), cast(uint)scale.x, cast(uint)scale.y);
        glScissor(cast(uint)absPos.x, cast(uint)(eventManager.windowHeight - absPos.y), cast(uint)scale.x, cast(uint)scale.y);
        glEnable(GL_SCISSOR_TEST);
        
        glClearColor(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        aspectRatio = scale.x / scale.y;
        
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        gluPerspective(fovY, aspectRatio, 0.1, 1000.0);
        glMatrixMode(GL_MODELVIEW);
        
        glPushMatrix();
        glLoadIdentity();
        camera.bind(dt);
        glEnable(GL_DEPTH_TEST);
        foreach(d; drawables.data)
            d.draw(dt);
            
        glEnable(GL_LIGHTING);
        glEnable(GL_LIGHT0);
        glLightfv(GL_LIGHT0, GL_POSITION, lightPosition.arrayof.ptr);
        if (scene)
            scene.draw(dt);
        glDisable(GL_LIGHTING);
        
        camera.unbind();
        glPopMatrix();
        
        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);
        
        glDisable(GL_SCISSOR_TEST);
        glScissor(viewport[0], viewport[1], viewport[2], viewport[3]);
        glViewport(viewport[0], viewport[1], viewport[2], viewport[3]);
    }
}