varying vec3 lightVec;
varying vec3 eyeVec;

void main()
{
    gl_TexCoord[0] = gl_MultiTexCoord0;

    // Building the matrix Eye Space -> Tangent Space
    vec3 n = normalize(gl_NormalMatrix * gl_Normal);
    vec3 t = normalize(gl_NormalMatrix * gl_Color.xyz);
    vec3 b = cross(n, t);

    vec3 vertexPosition = vec3(gl_ModelViewMatrix * gl_Vertex);
    vec3 lightDir = normalize(gl_LightSource[0].position.xyz - vertexPosition);

    vec3 v;
    v.x = dot (lightDir, t);
    v.y = dot (lightDir, b);
    v.z = dot (lightDir, n);
    lightVec = normalize (v);

    v.x = dot (vertexPosition, t);
    v.y = dot (vertexPosition, b);
    v.z = dot (vertexPosition, n);
    eyeVec = -normalize (v);

    gl_Position = ftransform();
}

