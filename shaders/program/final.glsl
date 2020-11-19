

/* 
BSL Shaders v7.2.01 by Capt Tatsu 
https://bitslablab.com 
*/

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;
uniform vec2 texelSize;
//Uniforms//
uniform sampler2D colortex1;

uniform float viewWidth, viewHeight;

//Optifine Constants//
/*
const int colortex0Format = R11F_G11F_B10F; //main scene
const int colortex1Format = RGB8; //raw translucent, bloom, final scene
const int colortex2Format = RGBA16; //temporal data
const int colortex3Format = RGB8; //specular data
const int colortex7Format = RGB8;
const int gaux1Format = R8; //cloud alpha
const int gaux2Format = RGB10_A2; //reflection image
const int gaux3Format = RGB16; //normals
const int gaux4Format = RGB16; //fresnel
*/

const bool shadowHardwareFiltering = true;

const int noiseTextureResolution = 512;

const float drynessHalflife = 25.0;
const float wetnessHalflife = 200.0;

//Common Functions//
#if SHARPEN > 0
vec2 sharpenOffsets[4] = vec2[4](
	vec2( 1.0,  0.0),
	vec2( 0.0,  1.0),
	vec2(-1.0,  0.0),
	vec2( 0.0, -1.0)
);
float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

void SharpenFilter(inout vec3 color) {
    //Weights : 1 in the center, 0.5 middle, 0.25 corners
    vec3 albedoCurrent1 = texture2D(colortex1, texCoord + vec2(texelSize.x,texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
    vec3 albedoCurrent2 = texture2D(colortex1, texCoord + vec2(texelSize.x,-texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
    vec3 albedoCurrent3 = texture2D(colortex1, texCoord + vec2(-texelSize.x,-texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;
    vec3 albedoCurrent4 = texture2D(colortex1, texCoord + vec2(-texelSize.x,texelSize.y)/MC_RENDER_QUALITY*0.5).rgb;


    vec3 m1 = -0.5/3.5*color + albedoCurrent1/3.5 + albedoCurrent2/3.5 + albedoCurrent3/3.5 + albedoCurrent4/3.5;
    vec3 std = abs(color - m1) + abs(albedoCurrent1 - m1) + abs(albedoCurrent2 - m1) +
     abs(albedoCurrent3 - m1) + abs(albedoCurrent3 - m1) + abs(albedoCurrent4 - m1);
    float contrast = 1.0 - luma(std)/5.0;
    color = color*(1.0+(SHARPEN)*contrast) - (SHARPEN)/(1.0-0.5/3.5)*contrast*(m1 - 0.5/3.5*color);
}
#endif

//Program//
void main() {
	vec3 color = texture2D(colortex1, texCoord).rgb;

	#if SHARPEN > 0
	SharpenFilter(color);
	#endif

	gl_FragColor = vec4(color, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif