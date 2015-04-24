module derelict.ogg.theoradecfuncs;

extern(C):

private
{
    import derelict.util.compat;
    import derelict.ogg.theoradectypes;
    import derelict.ogg.oggtypes;
    import derelict.ogg.theoracodectypes;
}

extern(C)
{
    alias int function(th_info *_info,th_comment *_tc, th_setup_info **_setup,ogg_packet *_op) da_th_decode_headerin;
    alias th_dec_ctx* function(th_info *_info, th_setup_info *_setup) da_th_decode_alloc;
    alias void function(th_setup_info *_setup) da_th_setup_free;
    alias int function(th_dec_ctx *_dec,int _req,void *_buf, size_t _buf_sz) da_th_decode_ctl;
    alias int function(th_dec_ctx *_dec,ogg_packet *_op, ogg_int64_t *_granpos) da_th_decode_packetin;
    alias int function(th_dec_ctx *_dec, th_ycbcr_buffer _ycbcr) da_th_decode_ycbcr_out;
    alias void function(th_dec_ctx *_dec) da_th_decode_free;
}

mixin(gsharedString!() ~
"
    da_th_decode_headerin th_decode_headerin;
    da_th_decode_alloc th_decode_alloc;
    da_th_setup_free th_setup_free;
    da_th_decode_ctl th_decode_ctl;
    da_th_decode_packetin th_decode_packetin;
    da_th_decode_ycbcr_out th_decode_ycbcr_out;
    da_th_decode_free th_decode_free;
");

