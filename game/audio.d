module game.audio;

import std.stdio;
import std.conv;
import std.string;
import core.stdc.stdio;
import core.stdc.stdlib;
public import derelict.openal.al;
import dlib.math.vector;
public import dlib.audio.sound;
public import dlib.audio.io.wav;

class AudioPlayer
{
    ALCcontext* context;
    ALuint[] buffers;
    ALuint[] sources;

    this()
    {
        ALCchar* defaultDevice = cast(ALCchar*)alcGetString(null, ALC_DEFAULT_DEVICE_SPECIFIER);
        auto device = alcOpenDevice(defaultDevice);
        assert(device !is null, "Failed to open audio device");
        writefln("OpenAL device: %s", to!string(defaultDevice));
        context = alcCreateContext(device, null);
        alcMakeContextCurrent(context);
        alcProcessContext(context);
    }
    
    ALuint addBuffer(Sound s)
    {
        assert(s.channels == 1 || s.channels == 2);
        assert(s.bitDepth == 8 || s.bitDepth == 16);
    
        ALuint buffer;
        ALsizei size = cast(int)s.data.length;
        ALsizei frequency = s.sampleRate;
        ALenum format;
    
        if (s.channels == 1)
        {
            if (s.bitDepth == 8 )
                format = AL_FORMAT_MONO8;
            else if (s.bitDepth == 16)
                format = AL_FORMAT_MONO16;
        }
        else if (s.channels == 2)
        {
            if (s.bitDepth == 8 )
                format = AL_FORMAT_STEREO8;
            else if (s.bitDepth == 16)
                format = AL_FORMAT_STEREO16;
        }
    
        alGenBuffers(1, &buffer);
        alBufferData(buffer, format, cast(void*)s.data.ptr, size, frequency);
        
        buffers ~= buffer;
        
        return buffer;
    }
    
    ALuint addSource(ALuint buffer, Vector3f pos)
    {
        ALuint source;
        alGenSources(cast(ALuint)1, &source);

        alSourcef(source, AL_PITCH, 1);
        alSourcef(source, AL_GAIN, 1);
        alSource3f(source, AL_POSITION, pos.x, pos.y, pos.z);
        alSource3f(source, AL_VELOCITY, 0, 0, 0);
        alSourcei(source, AL_LOOPING, AL_FALSE);
        alSourcei(source, AL_BUFFER, buffer);
        
        sources ~= source;
        
        return source;
    }
    
    void setSourcePosition(ALuint source, Vector3f pos)
    {
        alSource3f(source, AL_POSITION, pos.x, pos.y, pos.z);
    }
    
    void setSourceBuffer(ALuint source, ALuint buffer)
    {
        alSourcei(source, AL_BUFFER, buffer);
    }
    
    void setSourceLooping(ALuint source, bool mode)
    {
        alSourcei(source, AL_LOOPING, mode);
    }
    
    void setSourceVolume(ALuint source, float vol)
    {
        alSourcef(source, AL_GAIN, vol);
    }
    
    void playSource(ALuint source)
    {
        alSourcePlay(source);
    }
    
    void stopSource(ALuint source)
    {
        alSourceStop(source);
    }
    
    bool isSourcePlaying(ALuint source)
    {
        ALint state;
        alGetSourcei(source, AL_SOURCE_STATE, &state);
        return (state == AL_PLAYING);
    }
    
    void setListener(Vector3f pos, Vector3f dir, Vector3f up)
    {
        ALfloat[6] listenerOri;
        listenerOri[0..3] = dir.arrayof;
        listenerOri[3..6] = up.arrayof;
        alListener3f(AL_POSITION, pos.x, pos.y, pos.z);
        alListener3f(AL_VELOCITY, 0, 0, 0);
        alListenerfv(AL_ORIENTATION, listenerOri.ptr);
    }
    
    void close()
    {
        for(size_t i = 0; i < sources.length; i++)
            alDeleteSources(1, &sources[i]);
        
        for(size_t i = 0; i < buffers.length; i++)    
            alDeleteBuffers(1, &buffers[i]);
            
        auto device = alcGetContextsDevice(context);
        alcMakeContextCurrent(null);
        alcDestroyContext(context);
        alcCloseDevice(device);
    }
}
