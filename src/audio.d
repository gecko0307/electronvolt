module audio;

import dlib.container.dict;
import dlib.text.str;
import dlib.math.vector;
import soloud;

__gshared
{
    Soloud audio;
    Dict!(WavStream, string) music;
    Dict!(Wav, string) sounds;
    int musicVoice;
    float soundEffectsVolume = 0.5f;
    float musicVolume = 0.5f;
}

void initSound()
{
    audio = audio.create();
    audio.init(audio.CLIP_ROUNDOFF | audio.LEFT_HANDED_3D);
    
    music = dict!(WavStream, string);
    sounds = dict!(Wav, string);
    
    setSoundEffectsVolume(0.5f);
    setMusicVolume(0.5f);
}

void playSound(string filename, bool checkPlaying = false)
{
    if ((filename in sounds) is null)
    {
        String filenameStr = String(filename);
        auto sound = Wav.create();
        sound.load(filenameStr.ptr);
        sounds[filename] = sound;
        filenameStr.free();
    }
    
    Wav sound = sounds[filename];
    
    if (checkPlaying == false || audio.countAudioSource(sound) == 0)
    {
        int soundVoice = audio.play(sound);
        audio.setVolume(soundVoice, soundEffectsVolume);
    }
}

void setSoundEffectsVolume(float vol)
{
    soundEffectsVolume = vol;
}

void playMusic(string filename, bool looping = true)
{
    if ((filename in music) is null)
    {
        String filenameStr = String(filename);
        auto track = WavStream.create();
        track.load(filenameStr.ptr);
        music[filename] = track;
        filenameStr.free();
    }
    
    musicVoice = audio.play(music[filename]);
    audio.setLooping(musicVoice, looping);
    audio.setVolume(musicVoice, musicVolume);
}

bool musicIsPlaying()
{
    return cast(bool)audio.isValidVoiceHandle(musicVoice);
}

void stopMusic()
{
    audio.stop(musicVoice);
}

void setMusicVolume(float vol)
{
    musicVolume = vol;
    audio.setVolume(musicVoice, vol);
}

void setListener(Vector3f cameraPosition, Vector3f cameraDirection, Vector3f cameraUp)
{
    audio.set3dListenerPosition(cameraPosition.x, cameraPosition.y, cameraPosition.z);
    audio.set3dListenerAt(cameraDirection.x, cameraDirection.y, cameraDirection.z);
    audio.set3dListenerUp(cameraUp.x, cameraUp.y, cameraUp.z);
    audio.update3dAudio();
}
