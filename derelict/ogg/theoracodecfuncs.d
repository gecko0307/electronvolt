module derelict.ogg.theoracodecfuncs;

extern(C):

private
{
    import derelict.util.compat;
    import derelict.ogg.oggtypes;
    import derelict.ogg.theoracodectypes;
}

extern(C)
{
    alias char* function() da_th_version_string;
    alias ogg_uint32_t function() da_th_version_number;
    alias ogg_int64_t function(void *_encdec, ogg_int64_t _granpos) da_th_granule_frame;
    alias double function(void *_encdec, ogg_int64_t _granpos) da_th_granule_time;
    alias int function(ogg_packet *_op) da_th_packet_isheader;
    alias int function(ogg_packet *_op) da_th_packet_iskeyframe;
    alias void function(th_info *_info) da_th_info_init;
    alias void function(th_info *_info) da_th_info_clear;
    alias void function(th_comment *_tc) da_th_comment_init;
    alias void function(th_comment *_tc, char *_comment) da_th_comment_add;
    alias void function(th_comment *_tc, char *_tag, char *_val) da_th_comment_add_tag;
    alias char* function(th_comment *_tc, char *_tag, int _count) da_th_comment_query;
    alias int function(th_comment *_tc, char *_tag) da_th_comment_query_count;
    alias void function(th_comment *_tc) da_th_comment_clear;
}

mixin(gsharedString!() ~
"
    da_th_version_string th_version_string;
    da_th_version_number th_version_number;
    da_th_granule_frame th_granule_frame;
    da_th_granule_time th_granule_time;
    da_th_packet_isheader th_packet_isheader;
    da_th_packet_iskeyframe th_packet_iskeyframe;
    da_th_info_init th_info_init;
    da_th_info_clear th_info_clear;
    da_th_comment_init th_comment_init;
    da_th_comment_add th_comment_add;
    da_th_comment_add_tag th_comment_add_tag;
    da_th_comment_query th_comment_query;
    da_th_comment_query_count th_comment_query_count;
    da_th_comment_clear th_comment_clear;
");

