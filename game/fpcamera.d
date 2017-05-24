module game.fpcamera;

import derelict.opengl.gl;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.quaternion;
import dlib.math.transformation;
import dlib.math.utils;
import dlib.math.interpolation;

import dgl.core.interfaces;
import dgl.core.event;
import dgl.graphics.camera;

class FirstPersonCamera: Camera
{
    Matrix4x4f transformation;
    Matrix4x4f gunTransformation;
    Vector3f position;
    Vector3f jumpVel = Vector3f(0, 0, 0);
    Vector3f eyePosition = Vector3f(0, 0, 0);
    Vector3f gunPosition = Vector3f(0, 0, 0);
    float turn = 0.0f;
    float pitch = 0.0f;
    float roll = 0.0f;
    float gunPitch = 0.0f;
    float gunRoll = 0.0f;
    Matrix4x4f worldTransInv;
    
    this(Vector3f position)
    {
        this.position = position;
    }
    
    Matrix4x4f worldTrans()
    {  
        Matrix4x4f m = translationMatrix(position + eyePosition);
        m *= rotationMatrix(Axis.y, degtorad(turn));
        m *= rotationMatrix(Axis.x, degtorad(pitch));
        m *= rotationMatrix(Axis.z, degtorad(roll));
        return m;
    }
    
    Matrix4x4f getTransformation()
    {
        return transformation;
    }
    
    Matrix4x4f getInvTransformation()
    {
        return worldTransInv;
    }
    
    void update(double dt)
    {
        transformation = worldTrans();
        
        gunTransformation = translationMatrix(position + eyePosition);
        gunTransformation *= rotationMatrix(Axis.y, degtorad(turn));
        gunTransformation *= rotationMatrix(Axis.x, degtorad(gunPitch));
        gunTransformation *= rotationMatrix(Axis.z, degtorad(gunRoll));
        gunTransformation *= translationMatrix(gunPosition);
        
        worldTransInv = transformation.inverse;
    }
}

class FirstPersonView: EventListener
{
    FirstPersonCamera camera;
    int prevMouseX;
    int prevMouseY;
    bool mouseControl = true;
    bool paused = false;

    this(EventManager emngr, Vector3f camPos)
    {
        super(emngr);
        camera = New!FirstPersonCamera(camPos);
        camera.turn = -90.0f;
        camera.eyePosition = Vector3f(0, 0.0f, 0);
        camera.gunPosition = Vector3f(0.15f, -0.2f, -0.2f);
        eventManager.setMouseToCenter();
        
        eventManager.showCursor(false);
    }

    ~this()
    {
        Delete(camera);
    }
    
    void switchMouseControl()
    {
        mouseControl = !mouseControl;
        eventManager.showCursor(!mouseControl);
    }
    
    override void onFocusLoss()
    {
        mouseControl = false;
        eventManager.showCursor(true);
    }
    
    override void onFocusGain()
    {
        if (!paused)
        {
            mouseControl = true;
            eventManager.showCursor(false);
        }
    }

    void update(double dt)
    {
        processEvents();
        
        if (!mouseControl)
            return;

        int hWidth = eventManager.windowWidth / 2;
        int hHeight = eventManager.windowHeight / 2;
        float turn_m = -(hWidth - eventManager.mouseX) * 0.2f;
        float pitch_m = (hHeight - eventManager.mouseY) * 0.2f;
        camera.pitch += pitch_m;
        camera.turn += turn_m;
        float gunPitchCoef = 0.95f;
        camera.gunPitch += pitch_m * gunPitchCoef;
        
        float pitchLimitMax = 80.0f;
        float pitchLimitMin = -80.0f;
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
        camera.update(dt);
    }

    Matrix4x4f getCameraMatrix()
    {
        return camera.getInvTransformation();
    }
}
