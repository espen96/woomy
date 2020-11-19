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

void SharpenFilter(inout vec3 color) {
	float mult = SHARPEN * 0.025;
	vec2 view = 1.0 / vec2(viewWidth, viewHeight);

	color *= SHARPEN * 0.1 + 1.0;

	for(int i = 0; i < 4; i++) {
		vec2 offset = sharpenOffsets[i] * view;
		color -= texture2D(colortex1, texCoord + offset).rgb * mult;
	}
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