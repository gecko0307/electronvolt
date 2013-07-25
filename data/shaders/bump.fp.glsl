uniform sampler2D atrium_Texture0;
uniform sampler2D atrium_Texture1;
//uniform sampler2D gl_Texture2;

varying vec3 lightVec;
varying vec3 eyeVec;

vec3 reflect (vec3 N, vec3 L) 
{ 
    return 2.0 * N * dot(N, L) - L; 
}

void main()
{ 
    vec4 Ca = gl_FrontMaterial.ambient; 
    vec4 Cd = gl_FrontMaterial.diffuse; 
    vec4 Cs = gl_FrontMaterial.specular; 
    float Csh = gl_FrontMaterial.shininess;

    //float scale = 0.06;
    //float bias = -scale * 0.5;

    //float height = texture2D(atrium_Texture2, gl_TexCoord[0].st).r;
    //float offset = height * scale + bias;
    //vec2 newTexCoord = gl_TexCoord[0].st + offset * eyeVec.xy;

    vec3 normal = 2.0 * texture2D(atrium_Texture1, gl_TexCoord[0].st).rgb - 1.0;
    normal = normalize(normal);

    vec4 diffTex = texture2D(atrium_Texture0, gl_TexCoord[0].st);
    float diffuse = max (dot (lightVec, normal), 0.0);

    //float specular = pow (max (dot (reflect (normal, lightVec), eyeVec), 0.0 ), Csh ); 

    vec3 R = reflect(normal, lightVec); 
    float specular = pow (max (dot (R, eyeVec), 0.0 ), Csh );

    gl_FragColor = Ca * diffTex + Cd * diffTex * diffuse + Cs * diffTex * specular;
    gl_FragColor.a = 1.0;
}

