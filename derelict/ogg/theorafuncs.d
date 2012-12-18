module derelict.ogg.theorafuncs;

private
{
    import derelict.util.compat;
    import derelict.ogg.theoratypes;
}

extern(C)
{
    alias char* function() da_theora_version_string;
    alias ogg_uint32_t function() da_theora_version_number;
    alias int function(theora_state *th, theora_info *ti) da_theora_encode_init;
    alias int function(theora_state *t, yuv_buffer *yuv) da_theora_encode_YUVin;
    alias int function( theora_state *t, int last_p, ogg_packet *op) da_theora_encode_packetout;
    alias int function(theora_state *t, ogg_packet *op) da_theora_encode_header;
    alias int function(theora_comment *tc, ogg_packet *op) da_theora_encode_comment;
    alias int function(theora_state *t, ogg_packet *op) da_theora_encode_tables;
    alias int function(theora_info *ci, theora_comment *cc, ogg_packet *op) da_theora_decode_header;
    alias int function(theora_state *th, theora_info *c) da_theora_decode_init;
    alias int function(theora_state *th,ogg_packet *op) da_theora_decode_packetin;
    alias int function(theora_state *th,yuv_buffer *yuv) da_theora_decode_YUVout;
    alias int function(ogg_packet *op) da_theora_packet_isheader;
    alias int function(ogg_packet *op) da_theora_packet_iskeyframe;
    alias int function(theora_info *ti) da_theora_granule_shift;
    alias ogg_int64_t function(theora_state *th,ogg_int64_t granulepos) da_theora_granule_frame;
    alias double function(theora_state *th,ogg_int64_t granulepos) da_theora_granule_time;
    alias void function(theora_info *c) da_theora_info_init;
    alias void function(theora_info *c) da_theora_info_clear;
    alias void function(theora_state *t) da_theora_clear;
    alias void function(theora_comment *tc) da_theora_comment_init;
    alias void function(theora_comment *tc, char* comment) da_theora_comment_add;
    alias void function(theora_comment *tc, char* tag, char* value) da_theora_comment_add_tag;
    alias char* function(theora_comment *tc, char* tag, int count) da_theora_comment_query;
    alias int function(theora_comment *tc, char* tag) da_theora_comment_query_count;
    alias void function(theora_comment *tc) da_theora_comment_clear;
    alias int function(theora_state *th,int req,void *buf,size_t buf_sz) da_theora_control;
}

mixin(gsharedString!() ~
"
    da_theora_version_string theora_version_string;
    da_theora_version_number theora_version_number;
    da_theora_encode_init theora_encode_init;
    da_theora_encode_YUVin theora_encode_YUVin;
    da_theora_encode_packetout theora_encode_packetout;
    da_theora_encode_header theora_encode_header;
    da_theora_encode_comment theora_encode_comment;
    da_theora_encode_tables theora_encode_tables;
    da_theora_decode_header theora_decode_header;
    da_theora_decode_init theora_decode_init;
    da_theora_decode_packetin theora_decode_packetin;
    da_theora_decode_YUVout theora_decode_YUVout;
    da_theora_packet_isheader theora_packet_isheader;
    da_theora_packet_iskeyframe theora_packet_iskeyframe;
    da_theora_granule_shift theora_granule_shift;
    da_theora_granule_frame theora_granule_frame;
    da_theora_granule_time theora_granule_time;
    da_theora_info_init theora_info_init;
    da_theora_info_clear theora_info_clear;
    da_theora_clear theora_clear;
    da_theora_comment_init theora_comment_init;
    da_theora_comment_add theora_comment_add;
    da_theora_comment_add_tag theora_comment_add_tag;
    da_theora_comment_query theora_comment_query;
    da_theora_comment_query_count theora_comment_query_count;
    da_theora_comment_clear theora_comment_clear;
    da_theora_control theora_control;
");

