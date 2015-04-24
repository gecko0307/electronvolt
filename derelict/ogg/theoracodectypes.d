module derelict.ogg.theoracodectypes;

private
{
    import derelict.ogg.oggtypes;
}

extern(C):

enum
{
    TH_EFAULT        =    -1  ,
    TH_EINVAL        =    -10 ,
    TH_EBADHEADER    =    -20 ,
    TH_ENOTFORMAT    =    -21 ,
    TH_EVERSION        =    -22 ,
    TH_EIMPL        =    -23 ,
    TH_EBADPACKET    =    -24 ,
    TH_DUPFRAME        =    1   ,
}

enum th_colorspace
{
    TH_CS_UNSPECIFIED,
    TH_CS_ITU_REC_470M,
    TH_CS_ITU_REC_470BG,
    TH_CS_NSPACES,
}
enum
{
    TH_CS_UNSPECIFIED,
    TH_CS_ITU_REC_470M,
    TH_CS_ITU_REC_470BG,
    TH_CS_NSPACES,
}

enum th_pixel_fmt
{
    TH_PF_420,
    TH_PF_RSVD,
    TH_PF_422,
    TH_PF_444,
    TH_PF_NFORMATS,
}
enum
{
    TH_PF_420,
    TH_PF_RSVD,
    TH_PF_422,
    TH_PF_444,
    TH_PF_NFORMATS,
}

struct th_img_plane
{
    int            width;
    int            height;
    int            stride;
    ubyte *data;
}

alias th_img_plane[3] th_ycbcr_buffer;

struct th_info
{
    ubyte version_major;
    ubyte version_minor;
    ubyte version_subminor;

    ogg_uint32_t  frame_width;
    ogg_uint32_t  frame_height;
    ogg_uint32_t  pic_width;
    ogg_uint32_t  pic_height;
    ogg_uint32_t  pic_x;
    ogg_uint32_t  pic_y;
    ogg_uint32_t  fps_numerator;
    ogg_uint32_t  fps_denominator;
    ogg_uint32_t  aspect_numerator;
    ogg_uint32_t  aspect_denominator;

    th_colorspace colorspace;
    th_pixel_fmt  pixel_fmt;
    int           target_bitrate;
    int           quality;
    int           keyframe_granule_shift;
}

struct th_comment
{
    char **user_comments;
    int   *comment_lengths;
    int    comments;
    char  *vendor;
}

alias ubyte[64] th_quant_base;

struct th_quant_ranges
{
    int                  nranges;
    int           *sizes;
    th_quant_base *base_matrices;
}

struct th_quant_info
{
  ogg_uint16_t    dc_scale[64];
  ogg_uint16_t    ac_scale[64];
  ubyte   loop_filter_limits[64];
  th_quant_ranges qi_ranges[2][3];
}

enum
{
    TH_NHUFFMAN_TABLES    =    80,
    TH_NDCT_TOKENS    =    32,
}

struct th_huff_code
{
    ogg_uint32_t pattern;
    int          nbits;
}

