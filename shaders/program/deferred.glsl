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

varying vec3 sunVec, upVec, eastVec;

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;

uniform float blindFactor, nightVision;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;
uniform float worldTime;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;

#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
uniform vec3 cameraPosition, previousCameraPosition;

uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D noisetex;
#endif

//Optifine Constants//
#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
const bool colortex0MipmapEnabled = true;
const bool colortex5MipmapEnabled = true;
const bool colortex6MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.05, 0.0, 0.1) * 10.0;
float moonVisibility = clamp(dot(-sunVec,upVec) + 0.05, 0.0, 0.1) * 10.0;

#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

vec2 glowOffsets[16] = vec2[16](
    vec2( 0.0, -1.0),
    vec2(-1.0,  0.0),
    vec2( 1.0,  0.0),
    vec2( 0.0,  1.0),
    vec2(-1.0, -2.0),
    vec2( 0.0, -2.0),
    vec2( 1.0, -2.0),
    vec2(-2.0, -1.0),
    vec2( 2.0, -1.0),
    vec2(-2.0,  0.0),
    vec2( 2.0,  0.0),
    vec2(-2.0,  1.0),
    vec2( 2.0,  1.0),
    vec2(-1.0,  2.0),
    vec2( 0.0,  2.0),
    vec2( 1.0,  2.0)
);

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

float InterleavedGradientNoise() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 8.0);
}

void GlowOutline(inout vec3 color){
	for(int i = 0; i < 16; i++){
		vec2 glowOffset = glowOffsets[i] / vec2(viewWidth, viewHeight);
		float glowSample = texture2D(colortex3, texCoord.xy + glowOffset).b;
		if(glowSample < 0.5){
			if(i < 4) color.rgb = vec3(0.0);
			else color.rgb = vec3(0.5);
			break;
		}
	}
}

//Includes//
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/outline/outlineOffset.glsl"

#ifdef AO
#include "/lib/lighting/ambientOcclusion.glsl"
#endif

#ifdef BLACK_OUTLINE
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/outline/blackOutline.glsl"
#endif

#ifdef PROMO_OUTLINE
#include "/lib/outline/promoOutline.glsl"
#endif

#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
#include "/lib/util/encode.glsl"
#include "/lib/reflections/raytrace.glsl"
#include "/lib/reflections/complexFresnel.glsl"
#include "/lib/surface/materialDeferred.glsl"
#include "/lib/reflections/roughReflections.glsl"
#ifdef OVERWORLD
#include "/lib/atmospherics/clouds.glsl"
#include "/lib/atmospherics/sky.glsl"
#endif
#endif

//Program//
void main() {
    vec4 color      = texture2D(colortex0, texCoord);
	float z         = texture2D(depthtex0, texCoord).r;
	float isGlowing = texture2D(colortex3, texCoord).b;

	float dither = R2_dither();
	
	vec4 screenPos = vec4(texCoord, z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	if (z < 1.0) {
		#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
		float smoothness = 0.0, skyOcclusion = 0.0;
		vec3 normal = vec3(0.0), fresnel3 = vec3(0.0);

		GetMaterials(smoothness, skyOcclusion, normal, fresnel3, texCoord);

		if (length(fresnel3) > 0.0025) {
			vec4 reflection = vec4(0.0);
			vec3 skyReflection = vec3(0.0);
			
			reflection = RoughReflection(viewPos.xyz, normal, dither, smoothness);

			if (reflection.a < 1.0) {
				#ifdef OVERWORLD
				vec3 skyRefPos = reflect(normalize(viewPos.xyz), normal);
				skyReflection = GetSkyColor(skyRefPos, lightCol, true);
				
				#ifdef REFLECTION_ROUGH
				float cloudMixRate = smoothness * smoothness * (3.0 - 2.0 * smoothness);
				#else
				float cloudMixRate = 1.0;
				#endif

				#ifdef AURORA
				skyReflection += DrawAurora(skyRefPos * 100.0, dither, 12) * cloudMixRate;
				#endif

				#ifdef CLOUDS
				vec4 cloud = DrawCloud(skyRefPos * 100.0, dither, lightCol, ambientCol);
				skyReflection = mix(skyReflection, cloud.rgb, cloud.a * cloudMixRate);
				#endif

				float NoU = clamp(dot(normal, upVec), -1.0, 1.0);
				float NoE = clamp(dot(normal, eastVec), -1.0, 1.0);
				float vanillaDiffuse = (0.25 * NoU + 0.75) +
									   (0.5 - abs(NoE)) * (1.0 - abs(NoU)) * 0.1;
				vanillaDiffuse *= vanillaDiffuse;

				skyReflection = mix(
					vanillaDiffuse * vec3(0.001),
					skyReflection * (4.0 - 3.0 * eBS),
					skyOcclusion
				);
				#endif
				#ifdef NETHER
				skyReflection = netherCol.rgb * 0.04;
				#endif
				#ifdef END
				skyReflection = endCol.rgb * 0.025;
				#endif
			}

			reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));
			
			color.rgb += reflection.rgb * fresnel3;
		}
		#endif

		#ifdef AO
		color.rgb *= AmbientOcclusion(depthtex0, dither);
		#endif

		#ifdef PROMO_OUTLINE
		PromoOutline(color.rgb, depthtex0);
		#endif

		#ifdef FOG
		Fog(color.rgb, viewPos.xyz);
		#endif
	} else {
		#ifdef NETHER
		color.rgb = netherCol.rgb * 0.04;
		#endif
		#if defined END && !defined LIGHT_SHAFT
		color.rgb+= endCol.rgb * 0.025;
		#endif

		if (isEyeInWater == 2) {
			#ifdef EMISSIVE_RECOLOR
			color.rgb = pow(blocklightCol / BLOCKLIGHT_I, vec3(4.0)) * 2.0;
			#else
			color.rgb = vec3(1.0, 0.3, 0.01);
			#endif
		}

		if (blindFactor > 0.0) color.rgb *= 1.0 - blindFactor;
	}

	#ifdef BLACK_OUTLINE
	BlackOutline(color.rgb, depthtex0);
	#endif

	if (isGlowing > 0.5) GlowOutline(color.rgb);
    
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = color;
	#ifndef REFLECTION_PREVIOUS
	/*DRAWBUFFERS:05*/
	gl_FragData[1] = vec4(pow(color.rgb, vec3(0.125)) * 0.5, float(z < 1.0));
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec, eastVec;

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
	eastVec = normalize(gbufferModelView[0].xyz);
}

#endif
