module derelict.ogg.theoradec;

public
{
    import derelict.ogg.theoradectypes;
    import derelict.ogg.theoradecfuncs;
}

private
{
    import derelict.util.loader;
}

class DerelictTheoraDecLoader : SharedLibLoader
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
        bindFunc(cast(void**)&th_decode_headerin, "th_decode_headerin");
        bindFunc(cast(void**)&th_decode_alloc, "th_decode_alloc");
        bindFunc(cast(void**)&th_setup_free, "th_setup_free");
        bindFunc(cast(void**)&th_decode_ctl, "th_decode_ctl");
        bindFunc(cast(void**)&th_decode_packetin, "th_decode_packetin");
        bindFunc(cast(void**)&th_decode_ycbcr_out, "th_decode_ycbcr_out");
        bindFunc(cast(void**)&th_decode_free, "th_decode_free");
    }
}

DerelictTheoraDecLoader DerelictTheoraDec;

static this()
{
    DerelictTheoraDec = new DerelictTheoraDecLoader();
}

static ~this()
{
    if (SharedLibLoader.isAutoUnloadEnabled())
        DerelictTheoraDec.unload();
}

