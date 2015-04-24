module derelict.ogg.theoracodec;

public
{
    import derelict.ogg.theoracodectypes;
    import derelict.ogg.theoracodecfuncs;
}

private
{
    import derelict.util.loader;
}

class DerelictTheoraCodecLoader : SharedLibLoader
{
public:
    this()
    {
        super(
            "theoradec.dll, libtheoradec.dll",
            "libtheoradec.so, libtheoradec.so.1",
            "libtheoradec.dynlib"
        );
    }

protected:
    override void loadSymbols()
    {
        bindFunc(cast(void**)&th_version_string, "th_version_string");
        bindFunc(cast(void**)&th_version_number, "th_version_number");
        bindFunc(cast(void**)&th_granule_frame, "th_granule_frame");
        bindFunc(cast(void**)&th_granule_time, "th_granule_time");
        bindFunc(cast(void**)&th_packet_isheader, "th_packet_isheader");
        bindFunc(cast(void**)&th_packet_iskeyframe, "th_packet_iskeyframe");
        bindFunc(cast(void**)&th_info_init, "th_info_init");
        bindFunc(cast(void**)&th_info_clear, "th_info_clear");
        bindFunc(cast(void**)&th_comment_init, "th_comment_init");
        bindFunc(cast(void**)&th_comment_add, "th_comment_add");
        bindFunc(cast(void**)&th_comment_add_tag, "th_comment_add_tag");
        bindFunc(cast(void**)&th_comment_query, "th_comment_query");
        bindFunc(cast(void**)&th_comment_query_count, "th_comment_query_count");
        bindFunc(cast(void**)&th_comment_clear, "th_comment_clear");
    }
}

DerelictTheoraCodecLoader DerelictTheoraCodec;

static this()
{
    DerelictTheoraCodec = new DerelictTheoraCodecLoader();
}

static ~this()
{
    if (SharedLibLoader.isAutoUnloadEnabled())
        DerelictTheoraCodec.unload();
}

