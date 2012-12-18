module derelict.ogg.theoratypes;

public
{
    import derelict.ogg.oggtypes;
    //import derelict.ogg.theoracodec;
    //import derelict.ogg.theoraenc;
    //import derelict.ogg.theoradec;
}

extern(C):

struct yuv_buffer
{
    int   y_width;      /**< Width of the Y' luminance plane */
    int   y_height;     /**< Height of the luminance plane */
    int   y_stride;     /**< Offset in bytes between successive rows */

    int   uv_width;     /**< Width of the Cb and Cr chroma planes */
    int   uv_height;    /**< Height of the chroma planes */
    int   uv_stride;    /**< Offset between successive chroma rows */
    ubyte *y;   /**< Pointer to start of luminance data */
    ubyte *u;   /**< Pointer to start of Cb data */
    ubyte *v;   /**< Pointer to start of Cr data */

}

enum theora_colorspace
{
    OC_CS_UNSPECIFIED,    /**< The colorspace is unknown or unspecified */
    OC_CS_ITU_REC_470M,   /**< This is the best option for 'NTSC' content */
    OC_CS_ITU_REC_470BG,  /**< This is the best option for 'PAL' content */
    OC_CS_NSPACES         /**< This marks the end of the defined colorspaces */
}
enum
{
    OC_CS_UNSPECIFIED,    /**< The colorspace is unknown or unspecified */
    OC_CS_ITU_REC_470M,   /**< This is the best option for 'NTSC' content */
    OC_CS_ITU_REC_470BG,  /**< This is the best option for 'PAL' content */
    OC_CS_NSPACES         /**< This marks the end of the defined colorspaces */
}

enum theora_pixelformat
{
    OC_PF_420,    /**< Chroma subsampling by 2 in each direction (4:2:0) */
    OC_PF_RSVD,   /**< Reserved value */
    OC_PF_422,    /**< Horizonatal chroma subsampling by 2 (4:2:2) */
    OC_PF_444,    /**< No chroma subsampling at all (4:4:4) */
}
enum
{
    OC_PF_420,    /**< Chroma subsampling by 2 in each direction (4:2:0) */
    OC_PF_RSVD,   /**< Reserved value */
    OC_PF_422,    /**< Horizonatal chroma subsampling by 2 (4:2:2) */
    OC_PF_444,    /**< No chroma subsampling at all (4:4:4) */
}

struct theora_info
{
    ogg_uint32_t  width;		/**< encoded frame width  */
    ogg_uint32_t  height;		/**< encoded frame height */
    ogg_uint32_t  frame_width;	/**< display frame width  */
    ogg_uint32_t  frame_height;	/**< display frame height */
    ogg_uint32_t  offset_x;	/**< horizontal offset of the displayed frame */
    ogg_uint32_t  offset_y;	/**< vertical offset of the displayed frame */
    ogg_uint32_t  fps_numerator;	    /**< frame rate numerator **/
    ogg_uint32_t  fps_denominator;    /**< frame rate denominator **/
    ogg_uint32_t  aspect_numerator;   /**< pixel aspect ratio numerator */
    ogg_uint32_t  aspect_denominator; /**< pixel aspect ratio denominator */
    theora_colorspace colorspace;	    /**< colorspace */
    int           target_bitrate;	    /**< nominal bitrate in bits per second */
    int           quality;  /**< Nominal quality setting, 0-63 */
    int           quick_p;  /**< Quick encode/decode */

    /* decode only */
    ubyte version_major;
    ubyte version_minor;
    ubyte version_subminor;

    void *codec_setup;

    /* encode only */
    int           dropframes_p;
    int           keyframe_auto_p;
    ogg_uint32_t  keyframe_frequency;
    ogg_uint32_t  keyframe_frequency_force;  /* also used for decode init to
                                              get granpos shift correct */
    ogg_uint32_t  keyframe_data_target_bitrate;
    ogg_int32_t   keyframe_auto_threshold;
    ogg_uint32_t  keyframe_mindistance;
    ogg_int32_t   noise_sensitivity;
    ogg_int32_t   sharpness;

    theora_pixelformat pixelformat;	/**< chroma subsampling mode to expect */
}
struct theora_state
{
  theora_info *i;
  ogg_int64_t granulepos;

  void *internal_encode;
  void *internal_decode;

}

struct theora_comment
{
  char **user_comments;         /**< An array of comment string vectors */
  int   *comment_lengths;       /**< An array of corresponding string vector lengths in bytes */
  int    comments;              /**< The total number of comment string vectors */
  char  *vendor;                /**< The vendor string identifying the encoder, null terminated */

}

enum
{
	TH_DECCTL_GET_PPLEVEL_MAX               =   1,
	TH_DECCTL_SET_PPLEVEL                   =   3,
	TH_ENCCTL_SET_KEYFRAME_FREQUENCY_FORCE  =   4,
	TH_DECCTL_SET_GRANPOS                   =   5,
	TH_ENCCTL_SET_QUANT_PARAMS              =   2,
	TH_ENCCTL_SET_VP3_COMPATIBLE            =   10,
	TH_ENCCTL_GET_SPLEVEL_MAX               =   12,
	TH_ENCCTL_SET_SPLEVEL                   =   14,
}

enum
{
	OC_FAULT        =   -1  ,   /**< General failure */
	OC_EINVAL       =   -10 ,   /**< Library encountered invalid internal data */
	OC_DISABLED     =   -11 ,   /**< Requested action is disabled */
	OC_BADHEADER    =   -20 ,   /**< Header packet was corrupt/invalid */
	OC_NOTFORMAT    =   -21 ,   /**< Packet is not a theora packet */
	OC_VERSION      =   -22 ,   /**< Bitstream version is not handled */
	OC_IMPL         =   -23 ,   /**< Feature or action not implemented */
	OC_BADPACKET    =   -24 ,   /**< Packet is corrupt */
	OC_NEWPACKET    =   -25 ,   /**< Packet is an (ignorable) unhandled extension */
	OC_DUPFRAME     =   1   ,   /**< Packet is a dropped frame */
}

