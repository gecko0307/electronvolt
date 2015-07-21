uniform mat4 dgl_InvCamViewMatrix;

varying vec4 shadowCoord;

void main(void)
{
    gl_TexCoord[0] = gl_MultiTexCoord0;
    gl_TexCoord[1] = gl_MultiTexCoord1;

    // shadowCoord = textureMatrix * (invViewMatrix * (gl_ModelViewMatrix * gl_Vertex))
    vec4 worldPos = gl_ModelViewMatrix * gl_Vertex;
    worldPos = dgl_InvCamViewMatrix * worldPos;
    vec4 shadowCoord = gl_TextureMatrix[3] * worldPos;

	gl_Position = ftransform();
} 