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

varying vec3 sunVec, upVec;

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex7;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#ifdef LIGHT_SHAFT
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

//Attributes//

//Optifine Constants//
const bool colortex5Clear = false;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/lighting/ambientOcclusion.glsl"
#include "/lib/outline/outlineOffset.glsl"
#include "/lib/outline/promoOutline.glsl"

#ifdef LIGHT_SHAFT
#include "/lib/atmospherics/volumetricLight.glsl"
#endif

#ifdef BLACK_OUTLINE
#include "/lib/color/skyColor.glsl"
#include "/lib/color/blocklightColor.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/outline/blackOutline.glsl"
#endif


#define water_mat 0.1
#define trans_mat 0.15

bool matches(float l, float r) {
    return l > r - 0.01 && l < r + 0.01;
}
bool isTmixU(float mat, float mat_1, float mat_2){
    return (mat > mat_1 + 0.01) && (mat < mat_2 + 0.01);
}



//Program//
void main() {


	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;
	
	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;
    
	
    vec2 albedo_texcoord = texCoord.xy;
    vec2 rt_texcoord = texCoord.xy;
 
 
  vec3 ref = texture2D(colortex7, texCoord.xy).rgb;
    bool water = matches(ref.b,water_mat);
    float candidate = texture2D(colortex7,ref.xy + texCoord.xy).b;
    if ((water && matches(candidate, water_mat)) || (isTmixU(ref.b, water_mat, trans_mat) && isTmixU(candidate, water_mat, trans_mat))) {
        albedo_texcoord.xy += ref.xy;
    }
    if (water) {
        rt_texcoord.xy = albedo_texcoord.xy;
    }
    

    z0 = texture2D(depthtex0,albedo_texcoord.xy).r;
    z1 = texture2D(depthtex1,albedo_texcoord.xy).r;
    vec4 color = texture2D(colortex0, albedo_texcoord.xy);
    vec3 translucent = texture2D(colortex1,rt_texcoord.xy).rgb;	
	
	
	
	
	
	
	
	
	#if defined AO || defined LIGHT_SHAFT
	float dither = R2_dither();
	#endif

	#ifdef AO
    float lz0 = GetLinearDepth(z0) * far;
	if (z1 - z0 > 0.0 && lz0 < 32.0) {
		if (dot(translucent, translucent) < 0.02) {
            float ao = AmbientOcclusion(depthtex0, dither);
            float aoMix = clamp(0.03125 * lz0, 0.0 , 1.0);
            color.rgb *= mix(ao, 1.0, aoMix);
        }
	}
	#endif

	#ifdef FOG
	if (isEyeInWater == 1.0) {
        vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
		vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;

		WaterFog(color.rgb, viewPos.xyz);
	}
	#endif

	
	#ifdef BLACK_OUTLINE
	float outlineMask = BlackOutlineMask(depthtex0, depthtex1);
	if (outlineMask > 0.5 || isEyeInWater > 0.5)
		BlackOutline(color.rgb, depthtex0);
	#endif
	
	#ifdef PROMO_OUTLINE
	if (z1 - z0 > 0.0) PromoOutline(color.rgb, depthtex0);
	#endif
	
	
	#ifdef LIGHT_SHAFT
	vec3 vl = getVolumetricRays(z0, z1, translucent, dither);
	#else
	vec3 vl = vec3(0.0);
    #endif
	
    /*DRAWBUFFERS:01*/
	gl_FragData[0] = color;
//	gl_FragData[0] = vec4(ref.rgb,0);	
	gl_FragData[1] = vec4(vl, 1.0);
	
    #ifdef REFLECTION_PREVIOUS
    /*DRAWBUFFERS:015*/
	gl_FragData[2] = vec4(pow(color.rgb, vec3(0.125)) * 0.5, float(z0 < 1.0));
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif
