module derelict.ogg.theoradectypes;

extern(C):

private
{
    import derelict.ogg.oggtypes;
    import derelict.ogg.theoracodectypes;
}

enum
{
    TH_DECCTL_GET_PPLEVEL_MAX = 1,
    TH_DECCTL_SET_PPLEVEL     = 3,
    TH_DECCTL_SET_GRANPOS     = 5,
    TH_DECCTL_SET_STRIPE_CB   = 7,
}

alias void function(void *_ctx, th_ycbcr_buffer _buf, int _yfrag0, int _yfrag_end) th_stripe_decoded_func;

struct th_stripe_callback
{
    void *ctx;
    th_stripe_decoded_func stripe_decoded;
}

struct th_dec_ctx { }
struct th_setup_info { }


