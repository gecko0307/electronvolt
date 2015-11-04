uniform sampler2D dgl_Texture0;
uniform vec2 dgl_WindowSize;

void main(void)
{     
    vec4 total = vec4(0.0, 0.0, 0.0, 1.0);
    vec2 pix = gl_FragCoord.xy;
    vec2 invScreenSize = vec2(1.0 / dgl_WindowSize.x, 1.0 / dgl_WindowSize.y);
    const float radius = 16.0;

    for (float kx = -radius; kx <= radius; kx++)
    {
        total += texture2D(dgl_Texture0, gl_TexCoord[0].xy + vec2(kx, 0) * invScreenSize);
    }

    total /= (radius * 2.0 + 1.0);
    total *= 0.8;
        
    gl_FragColor = total;
    //gl_FragColor.a = 1.0;
}