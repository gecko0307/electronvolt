module photon.multimedia.ogvplayer;

private
{
    import std.stdio;
    import std.string;
    import std.math;

    import derelict.opengl.gl;
    import derelict.opengl.glu;
    import derelict.ogg.ogg;
    import derelict.ogg.theora;
    import derelict.ogg.vorbis;
}

struct OgvPlayer
{
    ogg_stream_state videoStream;
	ogg_stream_state audioStream;
	
    ogg_sync_state syncState;
    ogg_page oggPage;
	
    ogg_packet oggTheoraPacket;
	ogg_packet oggVorbisPacket;
	
	//Theora
    theora_comment theoraComment;
    theora_info theoraInfo;
    theora_state theoraState;
	
	//Vorbis
    vorbis_comment vorbisComment;
    vorbis_info vorbisInfo;
    vorbis_dsp_state vorbisDSPState;
    //vorbis_block vorbisBlock;

    std.c.stdio.FILE* ogvFile;

    bool videoOpened = false;
    uint videoTimer = 0;
    uint lastVideoFrame = 0;
    uint frameWidth = 0;
    uint frameHeight = 0;
    float framesPerSecond = 0.0f;
    bool stopped = true;

    yuv_buffer YUVFrame;

    GLuint videoTexture;

    ubyte[] buffer;
	
	// Audio
    // PCM frequency, usualy 44100 Hz
    int freq;
    //! Mono or stereo
    int numChannels;
	
    void openFile(string filename)
    {
        ogg_stream_clear(&videoStream);
        ogg_sync_init(&syncState);
        theora_comment_init(&theoraComment);
        theora_info_init(&theoraInfo);
        ogvFile = std.c.stdio.fopen(toStringz(filename), "rb");

        bool dataFound = false;        int theoraPacketsFound = 0;
        int vorbisPacketsFound = 0;
        while (!dataFound)
        {
            if (!bufferData())
                break;

            while (ogg_sync_pageout(&syncState, &oggPage) > 0)
            {
                if (!ogg_page_bos(&oggPage))
                {
                    dataFound = true;
                    ogg_stream_pagein(&videoStream, &oggPage);
                    break;
                }
                else
                {
                    ogg_stream_state test;
                    ogg_stream_init(&test, ogg_page_serialno(&oggPage));
                    ogg_stream_pagein(&test, &oggPage);
                    ogg_stream_packetout(&test, &oggTheoraPacket);

                    if (!theoraPacketsFound && theora_decode_header(&theoraInfo, &theoraComment, &oggTheoraPacket) >= 0)
                    {
                        videoStream = test;
                        theoraPacketsFound++;
                    }
                    else
                        ogg_stream_clear(&test);
                }
            }
        }

        if (theoraPacketsFound)
        {
            int err;
            // we need 3 header packets for any logical stream (theora, vorbis, etc.)
            while (theoraPacketsFound < 3)
            {
                err = ogg_stream_packetout(&videoStream, &oggTheoraPacket);
                if (err < 0)
                    // stream error (corrupted stream?)
                    break;
                if (err > 0)
                {
                    if (theora_decode_header(&theoraInfo, &theoraComment, &oggTheoraPacket) >= 0)
                        theoraPacketsFound++;
                    else
                        // stream error (corrupted stream?)
                        break;
                }

                if (!err)
                {
                    if (ogg_sync_pageout(&syncState, &oggPage) > 0)
                        ogg_stream_pagein(&videoStream, &oggPage);
                    else
                    {
                        if (!bufferData())
                            break;
                    }
                }
            }
        }

        if (theoraPacketsFound)
        {
            writeln("Packets found: ", theoraPacketsFound);
            if (0 == theora_decode_init(&theoraState, &theoraInfo))
            {
                frameWidth = theoraInfo.frame_width;
                frameHeight = theoraInfo.frame_height;
                framesPerSecond = cast(float)(theoraInfo.fps_numerator) / cast(float)(theoraInfo.fps_denominator);
                videoTimer = 0;
                stopped = false;

                writefln("Frame width: %s", frameWidth);
                writefln("Frame height: %s", frameHeight);
                writefln("FPS: %s", framesPerSecond);

                createBuffer();
            }
        }
    }

    int bufferData()
    {
        enum int syncBufferSize = 4096;
        byte* buffer = ogg_sync_buffer(&syncState, syncBufferSize);
        int bytes = fread(buffer, 1, syncBufferSize, ogvFile);
        ogg_sync_wrote(&syncState, bytes);
        return bytes;
    }

    void createBuffer()
    {
        buffer = new ubyte[1024 * 512 * 4];
		glEnable(GL_TEXTURE);
		glEnable(GL_TEXTURE_2D);
        glGenTextures(1, &videoTexture);
        glBindTexture(GL_TEXTURE_2D, videoTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1024, 512, 0, GL_RGBA, GL_UNSIGNED_BYTE, cast(void*)buffer.ptr);
    }

    void updateBuffer()
    {
        getFrameRGB(buffer.ptr);
        glBindTexture(GL_TEXTURE_2D, videoTexture);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 1024, 512, GL_RGBA, GL_UNSIGNED_BYTE, cast(void*)buffer.ptr);
		glBindTexture(GL_TEXTURE_2D, 0);
		//glBindTexture(GL_TEXTURE_2D, textureID);    //A texture you have already created with glTexImage2D
        //glCopyTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 0, 0, width, height);   //Copy back buffer to texture
    }
/*
    void getFrameYUV444(ubyte* outFrame)
    {
        for (int y = 0; y < frameHeight; ++y)
        {
            for (int x = 0; x < frameWidth; ++x)
            {
                int offset = (x + y * frameWidth) * 4;
                int xx = x >> 1;
                int yy = y >> 1;

                outFrame[offset + 0] = YUVFrame.y[x  +  y * YUVFrame. y_stride];
                outFrame[offset + 1] = YUVFrame.u[xx + yy * YUVFrame.uv_stride];
                outFrame[offset + 2] = YUVFrame.v[xx + yy * YUVFrame.uv_stride];
            }
        }
    }
*/
    int clip(int t)
    {
        return ((t < 0) ? (0) : ((t > 255) ? 255 : t));
    }

    void getFrameRGB(ubyte* outFrame)
    {
        for (int y = 0; y < frameHeight; ++y)
        {
            for (int x = 0; x < frameWidth; ++x)
            {
                int off = x + y * 1024;
                int xx = x >> 1;
                int yy = y >> 1;

                int Y = cast(int)(YUVFrame.y[x  +  y * YUVFrame. y_stride]) - 16;
                int U = cast(int)(YUVFrame.u[xx + yy * YUVFrame.uv_stride]) - 128;
                int V = cast(int)(YUVFrame.v[xx + yy * YUVFrame.uv_stride]) - 128;

                outFrame[off * 4 + 0] = cast(ubyte)clip((298 * Y           + 409 * V + 128) >> 8);
                outFrame[off * 4 + 1] = cast(ubyte)clip((298 * Y - 100 * U - 208 * V + 128) >> 8);
                outFrame[off * 4 + 2] = cast(ubyte)clip((298 * Y + 516 * U           + 128) >> 8);
            }
        }
    }

    void closeTheora()
    {
        ogg_stream_clear(&videoStream);
        theora_clear(&theoraState);
        theora_comment_clear(&theoraComment);
        theora_info_clear(&theoraInfo);
        ogg_sync_clear(&syncState);

        //delete buffer;
        fclose(ogvFile);
    }

    void decodeVideoFrame()
    {
        // grab some data into ogg packet
        while (ogg_stream_packetout(&videoStream, &oggTheoraPacket) <= 0)
        {
            // if no data in video stream
            if (!bufferData())
            {
                stopped = true;
                return;
            }

            //  grab all decoded ogg pages into our video stream
            while (ogg_sync_pageout(&syncState, &oggPage) > 0)
                ogg_stream_pagein(&videoStream, &oggPage);
        }

        // load packet into theora decoder
        if (0 == theora_decode_packetin(&theoraState, &oggTheoraPacket))
        {
            // if decoded, get YUV frame
            theora_decode_YUVout(&theoraState, &YUVFrame);
        }
        else
            stopped = true;
    }

    // advance video timer by delta time in milliseconds (dt)
    uint advance(uint dt)
    {
        if (stopped)
            return lastVideoFrame;

        videoTimer += dt;

        // calculate current frame
        uint curFrame = cast(uint)(floor(cast(float)(videoTimer) * framesPerSecond * 0.001f));
        if (lastVideoFrame != curFrame)
        {
             lastVideoFrame = curFrame;
             decodeVideoFrame();
             if (stopped)
                 closeTheora();
             else
                 updateBuffer();
        }

        return curFrame;
    }

    void draw(uint delta)
    {
        advance(delta);
        glColor4f(1.0f, 1.0f, 1.0f, 1.0f);
		glEnable(GL_TEXTURE);
		glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, videoTexture);
        glBegin(GL_QUADS);
        glTexCoord2f(0.0f, 1.0f); glVertex2i(0, 0);
        glTexCoord2f(1.0f, 1.0f); glVertex2i(1024, 0);
        glTexCoord2f(1.0f, 0.0f); glVertex2i(1024, 512);
        glTexCoord2f(0.0f, 0.0f); glVertex2i(0, 512);
        glEnd();
    }
}

