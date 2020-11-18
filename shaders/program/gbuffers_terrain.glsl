/* 
BSL Shaders v7.2.01 by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Extensions//

//Varyings//
varying float mat, recolor;

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
varying float dist;

varying vec3 binormal, tangent;
varying vec3 viewVector;

varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

#ifdef ADVANCED_MATERIALS
uniform ivec2 atlasSize;

uniform sampler2D specular;
uniform sampler2D normals;

#if REFLECTION_RAIN > 0
uniform float wetness;

uniform mat4 gbufferModelView;

uniform sampler2D noisetex;
#endif
#endif

#if DISTANT_FADE > 0
uniform float far;
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

#ifdef ADVANCED_MATERIALS
vec2 dcdx = dFdx(texCoord);
vec2 dcdy = dFdy(texCoord);
#endif

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float InterleavedGradientNoise() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 8.0);
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/lighting/forwardLighting.glsl"

#if AA == 2
#include "/lib/util/jitter.glsl"
#endif

#ifdef ADVANCED_MATERIALS
#include "/lib/color/specularColor.glsl"
#include "/lib/util/encode.glsl"
#include "/lib/reflections/complexFresnel.glsl"
#include "/lib/reflections/ggx.glsl"
#include "/lib/surface/directionalLightmap.glsl"
#include "/lib/surface/materialGbuffers.glsl"
#include "/lib/surface/parallax.glsl"

#if REFLECTION_RAIN > 0
#include "/lib/reflections/rainPuddles.glsl"
#endif
#endif

#if DISTANT_FADE > 0
#include "/lib/util/dither.glsl"
#endif

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * vec4(color.rgb, 1.0);
	vec3 newNormal = normal;

	#ifdef ADVANCED_MATERIALS
	vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
	float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
	float skipAdvMat = float(mat > 2.98 && mat < 3.02);
	
	#ifdef PARALLAX
	if(skipAdvMat < 0.5) {
		newCoord = GetParallaxCoord(parallaxFade);
		albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
	}
	#endif

	float smoothness = 0.0, skyOcclusion = 0.0;
	vec3 fresnel3 = vec3(0.0);
	#endif

	if (albedo.a > 0.001) {
		#ifdef TOON_LIGHTMAP
		vec2 lightmap = clamp(floor(lmCoord * 14.999 * (0.75 + 0.25 * color.a)) / 14, 0.0, 1.0);
		#else
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		#endif
		
		float foliage  = float(mat > 0.98 && mat < 1.02);

		float emissiveIntensity = 0.25 * EMISSIVE_BRIGHTNESS;
		float emissive = float(mat > 1.98 && mat < 2.02) * emissiveIntensity;
		float lava     = float(mat > 2.98 && mat < 3.02) * emissiveIntensity;
		
		#ifndef SHADOW_SUBSURFACE
		foliage = 0.0;
		#endif

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA == 2
		vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
		vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);

		#if DISTANT_FADE > 0
		float dither = Bayer64(gl_FragCoord.xy);
		if (AA == 2) dither = fract(frameTimeCounter * 16.0 + dither);
		#if DISTANT_FADE == 1
		float worldLength = length(worldPos);
		#elif DISTANT_FADE == 2
		float worldLength = length(worldPos.xz);
		#endif
		float alpha = (far - (worldLength + 20.0)) * 5.0 / far;
		if (alpha < dither) discard;
		#endif

		#ifdef ADVANCED_MATERIALS
		float metalness = 0.0, f0 = 0.0, ao = 1.0;
		vec3 normalMap = vec3(0.0, 0.0, 1.0);
		GetMaterials(smoothness, metalness, f0, emissive, ao, normalMap, newCoord, dcdx, dcdy);
		
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);

		if (normalMap.x > -0.999 && normalMap.y > -0.999)
			newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		float ec = GetLuminance(albedo.rgb) * 1.7;
		#ifdef EMISSIVE_RECOLOR
		if (recolor > 0.5) {
			albedo.rgb = blocklightCol * pow(ec, 1.5) / (BLOCKLIGHT_I * BLOCKLIGHT_I);
			albedo.rgb /= 0.7 * albedo.rgb + 0.7;
		}
		if (lava > 0.02) {
			albedo.rgb = pow(blocklightCol * ec / BLOCKLIGHT_I, vec3(2.0));
			albedo.rgb /= 0.5 * albedo.rgb + 0.5;
		}
		#else
		if (recolor > 0.5) {
			albedo.rgb *= ec * 0.25 + 0.5;
		}
		#endif

		#ifdef WHITE_WORLD
		albedo.rgb = vec3(0.5);
		#endif

		float NoL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float NoU = clamp(dot(newNormal, upVec), -1.0, 1.0);
		float NoE = clamp(dot(newNormal, eastVec), -1.0, 1.0);
		float vanillaDiffuse = (0.25 * NoU + 0.75) + (0.667 - abs(NoE)) * (1.0 - abs(NoU)) * 0.15;
			  vanillaDiffuse*= vanillaDiffuse * (foliage > 0.5 ? 1.8 : 1.0);

		float parallaxShadow = 1.0;
		#ifdef ADVANCED_MATERIALS
		vec3 rawAlbedo = albedo.rgb * 0.999 + 0.001;
		albedo.rgb *= ao * ao;

		#ifdef REFLECTION_SPECULAR
		float roughnessSqr = (1.0 - smoothness) * (1.0 - smoothness);
		albedo.rgb *= (1.0 - metalness * (1.0 - roughnessSqr));
		#endif

		float doParallax = 0.0;
		#ifdef SELF_SHADOW
		#ifdef OVERWORLD
		doParallax = float(lightmap.y > 0.0 && NoL > 0.0);
		#endif
		#ifdef END
		doParallax = float(NoL > 0.0);
		#endif
		
		if (doParallax > 0.5 && skipAdvMat < 0.5) {
			parallaxShadow = GetParallaxShadow(parallaxFade, newCoord, lightVec, tbnMatrix);
		}
		#endif

		#ifdef DIRECTIONAL_LIGHTMAP
		mat3 lightmapTBN = GetLightmapTBN(viewPos);
		lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, newNormal, lightmapTBN);
		lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, newNormal, lightmapTBN);
		#endif
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, color.a, NoL, vanillaDiffuse,
					parallaxShadow, emissive + lava, foliage);

		#ifdef ADVANCED_MATERIALS
		float puddles = 0.0;
		#if REFLECTION_RAIN > 0 && defined OVERWORLD
		NoU = clamp(NoU, 0.0, 1.0);
		
		#if REFLECTION_RAIN == 1
		puddles = GetPuddles(worldPos) * NoU * wetness;
		#else
		puddles = NoU * wetness;
		#endif
		
		#ifdef WEATHER_PERBIOME
		float weatherweight = isCold + isDesert + isMesa + isSavanna;
		puddles *= 1.0 - weatherweight;
		#endif
		
		puddles *= clamp(lightmap.y * 32.0 - 31.0, 0.0, 1.0);
		
		smoothness = mix(smoothness, 1.0, puddles);
		f0 = max(f0, puddles * 0.02);

		albedo.rgb *= 1.0 - (puddles * 0.15);

		if (puddles > 0.001 && rainStrength > 0.001) {
			mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);

			vec3 puddleNormal = GetPuddleNormal(worldPos, viewPos, tbnMatrix);
			newNormal = normalize(mix(newNormal, puddleNormal, puddles * rainStrength));
		}
		#endif

		skyOcclusion = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);
		
		vec3 baseReflectance = mix(vec3(f0), rawAlbedo, metalness);
		float fresnel = pow(clamp(1.0 + dot(newNormal, normalize(viewPos.xyz)), 0.0, 1.0), 5.0);

		fresnel3 = mix(baseReflectance, vec3(1.0), fresnel);
		#if MATERIAL_FORMAT == 0
		if (f0 >= 0.9 && f0 < 1.0) {
			baseReflectance = GetMetalCol(f0);
			fresnel3 = ComplexFresnel(fresnel, f0);
			#ifdef ALBEDO_METAL
			fresnel3 *= rawAlbedo;
			#endif
		}
		#endif
		
		float so = pow(max(ao * 2.0 - 1.0, 0.0), 2.0);
		fresnel3 *= so;
		albedo.rgb = albedo.rgb * (1.0 - fresnel3 * smoothness * smoothness * (1.0 - metalness));

		#if defined OVERWORLD || defined END
		vec3 specularColor = GetSpecularColor(lightmap.y, metalness, baseReflectance);
		
		albedo.rgb += GetSpecularHighlight(newNormal, viewPos, lightVec, smoothness, baseReflectance,
										   specularColor, shadow * so * vanillaDiffuse);
		#endif
		
		#if defined REFLECTION_SPECULAR && defined REFLECTION_ROUGH
		if (normalMap.x > -0.999 && normalMap.y > -0.999) {
			normalMap = mix(vec3(0.0, 0.0, 1.0), normalMap, smoothness);
			newNormal = mix(normalMap * tbnMatrix, newNormal, 1.0 - pow(1.0 - puddles, 4.0));
			newNormal = clamp(normalize(newNormal), vec3(-1.0), vec3(1.0));
		}
		#endif
		#endif
	} else albedo.a = 0.0;

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0367 */
	gl_FragData[1] = vec4(smoothness, skyOcclusion, 0.0, 1.0);
	gl_FragData[2] = vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[3] = vec4(fresnel3, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat, recolor;

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
varying float dist;

varying vec3 binormal, tangent;
varying vec3 viewVector;

varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#if AA == 2
uniform int frameCounter;

uniform float viewWidth, viewHeight;
#endif

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

#ifdef ADVANCED_MATERIALS
attribute vec4 at_tangent;
#endif

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

#if AA == 2
#include "/lib/util/jitter.glsl"
#endif

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(1.0));

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADVANCED_MATERIALS
	binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
								  
	viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = length(gl_ModelViewMatrix * gl_Vertex);

	vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = texCoord - midCoord;

	vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
	vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
	
	vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
	color = gl_Color;
	
	mat = 0.0; recolor = 0.0;

	if (mc_Entity.x == 10100 || mc_Entity.x == 10101 || mc_Entity.x == 10102 || mc_Entity.x == 10103 ||
	    mc_Entity.x == 10104 || mc_Entity.x == 10105 || mc_Entity.x == 10106 || mc_Entity.x == 10107 ||
	    mc_Entity.x == 10108 || mc_Entity.x == 10109)
		mat = 1.0;
	if (mc_Entity.x == 10200 || mc_Entity.x == 10207 || mc_Entity.x == 10210 || mc_Entity.x == 10214 ||
		mc_Entity.x == 10215 || mc_Entity.x == 10216 || mc_Entity.x == 10226 || mc_Entity.x == 10231 ||
		mc_Entity.x == 10249 || mc_Entity.x == 10250 || mc_Entity.x == 10251 || mc_Entity.x == 10252 ||
		mc_Entity.x == 10253)
		mat = 2.0;
	if (mc_Entity.x == 10248)
		mat = 3.0;

	if (mc_Entity.x == 10216 || mc_Entity.x == 10226 || mc_Entity.x == 10231 || mc_Entity.x == 10250 ||
		mc_Entity.x == 10251 || mc_Entity.x == 10253)
		recolor = 1.0;

	if (mc_Entity.x == 10215 || mc_Entity.x == 10231 || mc_Entity.x == 10248 || mc_Entity.x == 10249 ||
		mc_Entity.x == 10251)
		lmCoord.x = 1.0;
	if (mc_Entity.x == 10245)
		lmCoord.x -= 0.0667;

	if (mc_Entity.x == 10400)
		color.a = 1.0;

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz = WavingBlocks(position.xyz, istopv, lmCoord.y);

    #ifdef WORLD_CURVATURE
	position.y -= WorldCurvature(position.xz);
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	#if AA == 2
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif