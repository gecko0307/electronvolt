module derelict.ogg.theora;

public
{
    import derelict.ogg.theoratypes;
    import derelict.ogg.theorafuncs;
}

private
{
    import derelict.util.loader;
}

class DerelictTheoraLoader : SharedLibLoader
{
public:
    this()
    {
        super(
            "theora.dll, libtheora.dll",
            "libtheora.so, libtheora.so.0",
            "libtheora.dynlib"
        );
    }

protected:
    override void loadSymbols()
    {
        bindFunc(cast(void**)&theora_version_string, "theora_version_string");
        bindFunc(cast(void**)&theora_version_number, "theora_version_number");
        bindFunc(cast(void**)&theora_encode_init, "theora_encode_init");
        bindFunc(cast(void**)&theora_encode_YUVin, "theora_encode_YUVin");
        bindFunc(cast(void**)&theora_encode_packetout, "theora_encode_packetout");
        bindFunc(cast(void**)&theora_encode_header, "theora_encode_header");
        bindFunc(cast(void**)&theora_encode_comment, "theora_encode_comment");
        bindFunc(cast(void**)&theora_encode_tables, "theora_encode_tables");
        bindFunc(cast(void**)&theora_decode_header, "theora_decode_header");
        bindFunc(cast(void**)&theora_decode_init, "theora_decode_init");
        bindFunc(cast(void**)&theora_decode_packetin, "theora_decode_packetin");
        bindFunc(cast(void**)&theora_decode_YUVout, "theora_decode_YUVout");
        bindFunc(cast(void**)&theora_packet_isheader, "theora_packet_isheader");
        bindFunc(cast(void**)&theora_packet_iskeyframe, "theora_packet_iskeyframe");
        bindFunc(cast(void**)&theora_granule_shift, "theora_granule_shift");
        bindFunc(cast(void**)&theora_granule_frame, "theora_granule_frame");
        bindFunc(cast(void**)&theora_granule_time, "theora_granule_time");
        bindFunc(cast(void**)&theora_info_init, "theora_info_init");
        bindFunc(cast(void**)&theora_info_clear, "theora_info_clear");
        bindFunc(cast(void**)&theora_clear, "theora_clear");
        bindFunc(cast(void**)&theora_comment_init, "theora_comment_init");
        bindFunc(cast(void**)&theora_comment_add, "theora_comment_add");
        bindFunc(cast(void**)&theora_comment_add_tag, "theora_comment_add_tag");
        bindFunc(cast(void**)&theora_comment_query, "theora_comment_query");
        bindFunc(cast(void**)&theora_comment_query_count, "theora_comment_query_count");
        bindFunc(cast(void**)&theora_comment_clear, "theora_comment_clear");
        bindFunc(cast(void**)&theora_control, "theora_control");
    }
}

DerelictTheoraLoader DerelictTheora;

static this()
{
    DerelictTheora = new DerelictTheoraLoader();
}

static ~this()
{
    if (SharedLibLoader.isAutoUnloadEnabled())
        DerelictTheora.unload();
}
