uniform sampler2D dgl_Texture0;
uniform sampler2D dgl_Texture1;
uniform sampler2D dgl_Texture3;

varying vec4 shadowCoord;

void main (void) 
{
    vec4 tex = texture2D(dgl_Texture0, gl_TexCoord[0].st);
    vec4 lightmap = texture2D(dgl_Texture1, gl_TexCoord[1].st);
    float luminance = 1.0;
    
    //vec4 shadowCoordW = shadowCoord / shadowCoord.w;
    //shadowCoordW.z += 0.0005;
    //shadowCoordinateW.y = 1.0 - shadowCoordinateW.y;
    
    vec3 shadowCoordW = shadowCoord.xyz / shadowCoord.w;
   
    float depth = texture2D(dgl_Texture3, shadowCoordW.xy).r;
    
    //if (shadowCoord.w > 0.0)
        //luminance = dist < shadowCoordW.z ? 0.5 : 1.0;
    if (depth <= shadowCoordW.z)
        luminance = 0.5;
       
    gl_FragColor = tex * lightmap * luminance;
    gl_FragColor.a = 1.0;
}