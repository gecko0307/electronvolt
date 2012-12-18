module photon.multimedia.oggplayer;

private
{
    import core.thread;

    import std.stdio;
    import std.string;
    import std.file;
    import std.conv;
    import std.random;
    import std.path;
    //import std.array;

    import std.c.stdio;

    import derelict.util.compat;
    import derelict.sdl.sdl;

    import derelict.openal.al;
    import derelict.ogg.ogg;
    import derelict.ogg.vorbis;
    import derelict.ogg.vorbisenc;
    import derelict.ogg.vorbisfile;
}

struct Tags
{
    dstring title;
    dstring artist;
    dstring album;
    dstring comment;
    uint trackNumber = 0;    
}

enum BUFFER_SIZE = 4096 * 8;

final class OVStream
{
    OggVorbis_File oggStream;
    vorbis_info*    vorbisInfo;
    vorbis_comment* vorbisComment;

    ALuint[2] buffers; // front and back buffers
    ALuint source;     // audio source
    ALenum format;     // internal format

    Tags getTags(string path)
    {
        OggVorbis_File oggfile;
        std.c.stdio.FILE* oggFile = std.c.stdio.fopen(toStringz(path), "rb");
        ov_open(oggFile, &oggfile, null, 0);

        vorbisInfo = ov_info(&oggfile, -1);
        vorbisComment = ov_comment(&oggfile, -1);

        Tags newtags;
    
        newtags.title = to!dstring(baseName(path));
        newtags.artist = "<unknown artist>";
        newtags.album = "<unknown album>";

        for (int i = 0; i < vorbisComment.comments; i++)
        {
            char* cdata = vorbisComment.user_comments[i];
            dstring tag = to!dstring(to!string(cdata));
            if (tag.startsWith("TITLE=")) 
                newtags.title = tag.chompPrefix("TITLE=");
            else if (tag.startsWith("ARTIST=")) 
                newtags.artist = tag.chompPrefix("ARTIST=");
            else if (tag.startsWith("ALBUM=")) 
                newtags.album = tag.chompPrefix("ALBUM=");
            else if (tag.startsWith("TRACKNUMBER=")) 
                newtags.trackNumber = tag.chompPrefix("TRACKNUMBER=").to!uint;
            else
                newtags.comment = tag;
        }

        ov_clear(&oggfile);

        return newtags;        
    }

    void open(string path)
    {
        std.c.stdio.FILE* oggFile = std.c.stdio.fopen(toStringz(path), "rb");
        ov_open(oggFile, &oggStream, null, 0);

        vorbisInfo = ov_info(&oggStream, -1);
        vorbisComment = ov_comment(&oggStream, -1);

        if (vorbisInfo.channels == 1)
            format = AL_FORMAT_MONO16;
        else
            format = AL_FORMAT_STEREO16;

        alGenBuffers(2, buffers.ptr); check();
        alGenSources(1, &source); check();
        
        alSource3f(source, AL_POSITION,        0.0, 0.0, 0.0);
        alSource3f(source, AL_VELOCITY,        0.0, 0.0, 0.0);
        alSource3f(source, AL_DIRECTION,       0.0, 0.0, 0.0);
        alSourcef (source, AL_ROLLOFF_FACTOR,  0.0          );
        alSourcei (source, AL_SOURCE_RELATIVE, AL_TRUE      );
    }

    void release()
    {
        empty();
        alDeleteSources(1, &source); check();
        alDeleteBuffers(2, buffers.ptr); check();
        ov_clear(&oggStream);
    }

    void stop()
    {
        alSourceStop(source);
    }

    void display()
    {
        writeln("version         ", vorbisInfo._version);
        writeln("channels        ", vorbisInfo.channels);
        writeln("rate (hz)       ", vorbisInfo.rate);
        writeln("bitrate upper   ", vorbisInfo.bitrate_upper);
        writeln("bitrate nominal ", vorbisInfo.bitrate_nominal);
        writeln("bitrate lower   ", vorbisInfo.bitrate_lower);
        writeln("bitrate window  ", vorbisInfo.bitrate_window);
    }

    bool playback()
    {
        if (playing())
            return true;
        
        if (!stream(buffers[0]))
            return false;
     
        if(!stream(buffers[1]))
            return false;
        
        alSourceQueueBuffers(source, 2, buffers.ptr);
        alSourcePlay(source);
        
        return true;
    }

    bool playing()
    {
        ALenum state;
        alGetSourcei(source, AL_SOURCE_STATE, &state);
        return (state == AL_PLAYING);
    }

    bool update()
    {
        int processed;
        bool active = true;
        alGetSourcei(source, AL_BUFFERS_PROCESSED, &processed);

        while(processed>0)
        {
            processed--;
            ALuint buffer;
            alSourceUnqueueBuffers(source, 1, &buffer); check();
            active = stream(buffer);
            alSourceQueueBuffers(source, 1, &buffer); check();
        }

        if (!playing())
            alSourcePlay(source);

        return active;
    }

    bool stream(ALuint buffer)
    {
        byte data[BUFFER_SIZE];
        int  size = 0;
        int  section;
        int  result;
     
        while(size < BUFFER_SIZE)
        {
            result = ov_read(&oggStream, size + data.ptr, BUFFER_SIZE - size, 0, 2, 1, & section);
        
            if(result > 0)
                size += result;
            else
                if(result < 0)
                    throw new Exception(to!string(result));
            else
                break;
        }
        
        if(size == 0)
            return false;
     
        alBufferData(buffer, format, data.ptr, size, vorbisInfo.rate);
            check();
     
        return true;
    }

    void empty()
    {
        int queued;
        
        alGetSourcei(source, AL_BUFFERS_QUEUED, &queued);
        
        while(queued--)
        {
            ALuint buffer;
            alSourceUnqueueBuffers(source, 1, &buffer); check();
        }
    }

    private void check()
    {
        if (alGetError() != AL_NO_ERROR)
            throw new Exception("OpenAL error occured");
    }
}

class Playlist(T)
{
    public:

    void addToEnd(T val)
    {
        data ~= val;
    }

    void removeFromEnd()
    {
        assert (data.length>0);
        data.length -= 1;
    }

    T next()
    {
        assert (data.length>0);
        current++;
        if (current==data.length)
            current -= data.length;
        return data[current];
    }

    T prev()
    {
        assert (data.length>0);
        current--;
        if (current==-1)
            current += data.length;
        return data[current];
    }

    T random()
    {
        assert (data.length>0);
        current = uniform(0, data.length);
        return data[current];
    }

    bool isEmpty()
    {
        return (data.length==0);
    }

    int length()
    {
        return data.length;
    }

    private:

    T[] data;
    T current;
}

class OVPlayer
{
    public:
    OVStream stream;
    Thread audiothread;
    bool stopped = false;

    string[] tracks;
    Playlist!int plst;
    int current = -1;
    Tags[] metadata;
 
    static OVPlayer opCall()
    {
        if (_instance !is null) 
            return _instance;
        _instance = new OVPlayer();
        return _instance;
    }

    bool loadTracks(string path)
    {
        //string path2 = expandTilde("~/.dragon/") ~ path;
        if (exists(path)) 
        {
            writefln("Searching music in \"%s\"...", path);
            foreach (string name; dirEntries(path, SpanMode.depth))
            {
                string ext = extension(name);
                if (ext==".ogg")
                {
                    tracks ~= name;
                }
            }
        }
        //if (exists(path2)) { writefln("Searching music in \"%s\"...", path2); listdir(path2, &callback); }
        if (tracks.length>0) 
        { 
            writeln(tracks.length," track(s) found"); 
            foreach(i, song; tracks)
            {
                Tags newtags = stream.getTags(song);
                metadata ~= newtags;
                plst.addToEnd(i);
            }
            return true; 
        }
        else 
        { 
            writeln("No music found!"); 
            return false;
        }
    }

    void threadfunc()
    {
        bool running = true;
        while(running)
        {
            if (stopped) running = false;
            else 
            {
                running = stream.update();
                if (!running)
                {
                    stopStream();
                    current = plst.next();
                    startStream(tracks[current]);
                    running = true;
                }
            }
            SDL_Delay(10);
        }
        stopStream();
    }

    void startStream(string fname)
    {
        stream.open(fname);
        if(!stream.playback())
        {
            stream.release();
            throw new Exception("OGG refused to play");
        }        
    }

    void stopStream()
    {
        stream.stop();
        stream.release();        
    }

    void playTrack(int i)
    {
        if (tracks.length > 0)
        {
            stopped = false; 
            audiothread = new Thread( &threadfunc );
            startStream(tracks[i]);
            current = i;
            audiothread.start();
        }
    }

    void stop()
    {
        if (audiothread) 
        {
            if (audiothread.isRunning) 
            {
                stopped = true; 
                audiothread.join(); 
                delete audiothread;
                audiothread = null;
            }
        }
    }

    void playRandom()
    {
        stop();
        if (!plst.isEmpty) 
            playTrack(plst.random);
        else writeln("Track list is empty");
    }

    void playNext()
    {
        stop();
        if (!plst.isEmpty) playTrack(plst.next);
    }

    void playPrev()
    {
        stop();
        if (!plst.isEmpty) playTrack(plst.prev);
    }

    void release()
    {
        stop();
    }

    dstring getSongTitle()
    {
        if (metadata && current>-1) return metadata[current].title;
        else return "<unknown title>";
    }

    dstring getSongArtist()
    {
        if (metadata && current>-1) return metadata[current].artist;
        else return "<unknown artist>";
    }

    dstring getSongAlbum()
    {
        if (metadata && current>-1) return metadata[current].album;
        else return "<unknown album>";
    }

    private:
    this()
    {
        stream = new OVStream();        
        plst = new Playlist!int;
    }

    static OVPlayer _instance = null;
}


