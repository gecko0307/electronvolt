/*

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/
module derelict.ogg.vorbis;

public
{
    import derelict.ogg.vorbistypes;
    import derelict.ogg.vorbisfuncs;
}

private
{
    import derelict.util.loader;
}

class DerelictVorbisLoader : SharedLibLoader
{
public:
    this()
    {
        super(
            "vorbis.dll, libvorbis.dll",
            "libvorbis.so, libvorbis.so.0, libvorbis.so.0.3.0",
            ""
        );
    }

protected:
    override void loadSymbols()
    {
        bindFunc(cast(void**)&vorbis_info_init, "vorbis_info_init");
        bindFunc(cast(void**)&vorbis_info_clear, "vorbis_info_clear");
        bindFunc(cast(void**)&vorbis_info_blocksize, "vorbis_info_blocksize");
        bindFunc(cast(void**)&vorbis_comment_init, "vorbis_comment_init");
        bindFunc(cast(void**)&vorbis_comment_add, "vorbis_comment_add");
        bindFunc(cast(void**)&vorbis_comment_add_tag, "vorbis_comment_add_tag");
        bindFunc(cast(void**)&vorbis_comment_query, "vorbis_comment_query");
        bindFunc(cast(void**)&vorbis_comment_query_count, "vorbis_comment_query_count");
        bindFunc(cast(void**)&vorbis_comment_clear, "vorbis_comment_clear");
        bindFunc(cast(void**)&vorbis_block_init, "vorbis_block_init");
        bindFunc(cast(void**)&vorbis_block_clear, "vorbis_block_clear");
        bindFunc(cast(void**)&vorbis_dsp_clear, "vorbis_dsp_clear");
        bindFunc(cast(void**)&vorbis_granule_time, "vorbis_granule_time");
        //bindFunc(cast(void**)&vorbis_version_string, "vorbis_version_string");

        bindFunc(cast(void**)&vorbis_analysis_init, "vorbis_analysis_init");
        bindFunc(cast(void**)&vorbis_commentheader_out, "vorbis_commentheader_out");
        bindFunc(cast(void**)&vorbis_analysis_headerout, "vorbis_analysis_headerout");

        bindFunc(cast(void**)&vorbis_analysis_buffer, "vorbis_analysis_buffer");
        bindFunc(cast(void**)&vorbis_analysis_wrote, "vorbis_analysis_wrote");
        bindFunc(cast(void**)&vorbis_analysis_blockout, "vorbis_analysis_blockout");
        bindFunc(cast(void**)&vorbis_analysis, "vorbis_analysis");

        bindFunc(cast(void**)&vorbis_bitrate_addblock, "vorbis_bitrate_addblock");
        bindFunc(cast(void**)&vorbis_bitrate_flushpacket, "vorbis_bitrate_flushpacket");

        bindFunc(cast(void**)&vorbis_synthesis_headerin, "vorbis_synthesis_idheader");
        bindFunc(cast(void**)&vorbis_synthesis_headerin, "vorbis_synthesis_headerin");
        bindFunc(cast(void**)&vorbis_synthesis_init, "vorbis_synthesis_init");
        bindFunc(cast(void**)&vorbis_synthesis_restart, "vorbis_synthesis_restart");
        bindFunc(cast(void**)&vorbis_synthesis, "vorbis_synthesis");
        bindFunc(cast(void**)&vorbis_synthesis_trackonly, "vorbis_synthesis_trackonly");
        bindFunc(cast(void**)&vorbis_synthesis_blockin, "vorbis_synthesis_blockin");
        bindFunc(cast(void**)&vorbis_synthesis_pcmout, "vorbis_synthesis_pcmout");
        bindFunc(cast(void**)&vorbis_synthesis_lapout, "vorbis_synthesis_lapout");
        bindFunc(cast(void**)&vorbis_synthesis_read, "vorbis_synthesis_read");
        bindFunc(cast(void**)&vorbis_packet_blocksize, "vorbis_packet_blocksize");
        bindFunc(cast(void**)&vorbis_synthesis_halfrate, "vorbis_synthesis_halfrate");
        bindFunc(cast(void**)&vorbis_synthesis_halfrate_p, "vorbis_synthesis_halfrate_p");
    }
}

DerelictVorbisLoader DerelictVorbis;

static this()
{
    DerelictVorbis = new DerelictVorbisLoader();
}

static ~this()
{
    if(SharedLibLoader.isAutoUnloadEnabled())
        DerelictVorbis.unload();
}
