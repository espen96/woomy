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
varying float mat;
varying float dist;

varying vec2 texCoord, lmCoord;

varying vec3 normal, binormal, tangent;
varying vec3 sunVec, upVec, eastVec;
varying vec3 viewVector;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor, nightVision;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferProjection, gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2D gaux2;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#ifdef ADVANCED_MATERIALS
uniform ivec2 atlasSize;

uniform sampler2D specular;
uniform sampler2D normals;

#if REFLECTION_RAIN > 0
uniform float wetness;
#endif
#endif

//Optifine Constants//

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

float GetWaterHeightMap(vec3 worldPos, vec2 offset) {
    float noise = 0.0;
    
    vec2 wind = vec2(frametime) * 0.35 * WATER_SPEED;

	worldPos.xz -= worldPos.y * 0.2;

	#if WATER_NORMALS == 1
	offset /= 256.0;
	float noiseA = texture2D(noisetex, (worldPos.xz - wind * 1.4) / 256.0 + offset).g;
	float noiseB = texture2D(noisetex, (worldPos.xz + wind) / 48.0 + offset).g;
	#elif WATER_NORMALS == 2
	offset /= 256.0;
	float noiseA = texture2D(noisetex, (worldPos.xz - wind * 1.4) / 512.0 + offset).b;
	float noiseB = texture2D(noisetex, (worldPos.xz + wind) / 96.0 + offset).b;
	noiseA *= noiseA; noiseB *= noiseB;
	#endif
	
	#if WATER_NORMALS > 0
	noise = mix(noiseA, noiseB, WATER_DETAIL);
	#endif

    return -noise * WATER_BUMP;
}

vec3 GetParallaxWaves(vec3 worldPos, vec3 viewVector) {
	vec3 parallaxPos = worldPos;
	
	for(int i = 0; i < 4; i++) {
		float height = GetWaterHeightMap(parallaxPos, vec2(0.0)) + 0.25;
		parallaxPos.xz += height * viewVector.xy / dist;
	}
	return parallaxPos;
}

vec3 GetWaterNormal(vec3 worldPos, vec3 viewPos, vec3 viewVector) {
	vec3 waterPos = worldPos + cameraPosition;

	//waterPos = floor(waterPos * 16.0) / 16.0;

	#ifdef WATER_PARALLAX
	waterPos = GetParallaxWaves(waterPos, viewVector);
	#endif

	float normalOffset = WATER_SHARPNESS;
	
	float fresnel = pow(clamp(1.0 + dot(normalize(normal), normalize(viewPos)), 0.0, 1.0), 7.5);
	float normalStrength = 0.35 * (1.0 - fresnel);

	float h1 = GetWaterHeightMap(waterPos, vec2( normalOffset, 0.0));
	float h2 = GetWaterHeightMap(waterPos, vec2(-normalOffset, 0.0));
	float h3 = GetWaterHeightMap(waterPos, vec2(0.0,  normalOffset));
	float h4 = GetWaterHeightMap(waterPos, vec2(0.0, -normalOffset));

	float xDelta = (h1 - h2) / normalOffset;
	float yDelta = (h3 - h4) / normalOffset;

	vec3 normalMap = vec3(xDelta, yDelta, 1.0 - (xDelta * xDelta + yDelta * yDelta));
	return normalMap * normalStrength + vec3(0.0, 0.0, 1.0 - normalStrength);
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/specularColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/reflections/ggx.glsl"
#include "/lib/reflections/raytrace.glsl"
#include "/lib/reflections/simpleReflections.glsl"

#ifdef OVERWORLD
#include "/lib/atmospherics/clouds.glsl"
#include "/lib/atmospherics/sky.glsl"
#endif

#if AA == 2
#include "/lib/util/jitter.glsl"
#endif

#ifdef ADVANCED_MATERIALS
#include "/lib/reflections/complexFresnel.glsl"
#include "/lib/surface/directionalLightmap.glsl"
#include "/lib/surface/materialGbuffers.glsl"
#include "/lib/surface/parallax.glsl"

#if REFLECTION_RAIN > 0
#include "/lib/reflections/rainPuddles.glsl"
#endif
#endif







vec2 getRefraction(vec3 fragpos, vec3 wnormal) {
	float waterRefractionStrength = 1.015;
	//vec2 waterTexcoord = texcoord.xy;
	waterRefractionStrength *= mix(0.2, 1.0, exp(-pow(length(fragpos.xyz) * 0.04, 1.5)));
    vec2 waterTexcoord = wnormal.xy * waterRefractionStrength;//gl_FragCoord.xy/vec2(viewWidth,viewHeight) + 
    return waterTexcoord;
}






//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * vec4(color.rgb, 1.0);
	vec3 newNormal = normal;
	
	#ifdef ADVANCED_MATERIALS
	vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
	float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
	
	#ifdef PARALLAX
	newCoord = GetParallaxCoord(parallaxFade);
	albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
	#endif
	#endif

	float emissive = 0.0;

	vec3 vlAlbedo = vec3(1.0);

	if (albedo.a > 0.001) {
		#ifdef TOON_LIGHTMAP
		vec2 lightmap = clamp(floor(lmCoord * 14.999 * (0.75 + 0.25 * color.a)) / 14, 0.0, 1.0);
		#else
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		#endif
		
		float water       = float(mat > 0.98 && mat < 1.02);
		float translucent = float(mat > 1.98 && mat < 2.02);
		
		#ifndef REFLECTION_TRANSLUCENT
		translucent = 0.0;
		#endif

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#if AA == 2
		vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
		vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);

		float dither = R2_dither();

		#if DISTANT_FADE > 0
		if (AA == 2) dither = fract(frameTimeCounter * 16.0 + dither);
		#if DISTANT_FADE == 1
		float worldLength = length(worldPos);
		#elif DISTANT_FADE == 2
		float worldLength = length(worldPos.xz);
		#endif
		float alpha = (far - (worldLength + 20.0)) * 5.0 / far;
		if (alpha < dither) discard;
		#endif

		vec3 normalMap = vec3(0.0, 0.0, 1.0);
		
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);

		#if WATER_NORMALS == 1 || WATER_NORMALS == 2
		if (water > 0.5) {
			normalMap = GetWaterNormal(worldPos, viewPos, viewVector);
			newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
		}
		#endif

		#ifdef ADVANCED_MATERIALS
		float smoothness = 0.0, metalness = 0.0, f0 = 0.0, ao = 1.0, skyOcclusion = 0.0;
		if (water < 0.5) {		
			GetMaterials(smoothness, metalness, f0, emissive, ao, normalMap, newCoord, dcdx, dcdy);
			if (normalMap.x > -0.999 && normalMap.y > -0.999)
				newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
		}
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		#ifdef WHITE_WORLD
		albedo.rgb = vec3(0.5);
		#endif
		
		if (water > 0.5) {
			#if WATER_MODE == 0
			albedo.rgb = waterColor.rgb * waterColor.a;
			#elif WATER_MODE == 1
			albedo.rgb *= albedo.a;
			#elif WATER_MODE == 2
			float waterLuma = length(albedo.rgb / pow(color.rgb, vec3(2.2))) * 2.0;
			albedo.rgb = waterLuma * waterColor.rgb * waterColor.a * albedo.a;
			#elif WATER_MODE == 3
			albedo.rgb = color.rgb * color.rgb * 0.35;
			#endif
			albedo.a = waterAlpha;
		}

		vlAlbedo = mix(vec3(1.0), albedo.rgb, sqrt(albedo.a)) * (1.0 - pow(albedo.a, 64.0));

		float NoL = clamp(dot(newNormal, lightVec) * 1.01 - 0.01, 0.0, 1.0);

		float NoU = clamp(dot(newNormal, upVec), -1.0, 1.0);
		float NoE = clamp(dot(newNormal, eastVec), -1.0, 1.0);
		float vanillaDiffuse = (0.25 * NoU + 0.75) + (0.667 - abs(NoE)) * (1.0 - abs(NoU)) * 0.15;
			  vanillaDiffuse*= vanillaDiffuse;

		float parallaxShadow = 1.0;
		#ifdef ADVANCED_MATERIALS
		vec3 rawAlbedo = albedo.rgb * 0.999 + 0.001;
		albedo.rgb *= ao;

		#ifdef REFLECTION_SPECULAR
		float roughnessSqr = (1.0 - smoothness) * (1.0 - smoothness);
		albedo.rgb *= (1.0 - metalness * (1.0 - roughnessSqr));
		#endif
		
		#ifdef SELF_SHADOW
		if (lightmap.y > 0.0 && NoL > 0.0 && water < 0.5) {
			parallaxShadow = GetParallaxShadow(parallaxFade, newCoord, lightVec, tbnMatrix);
			NoL *= parallaxShadow;
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
				    parallaxShadow, emissive, 0.0);

		#ifdef ADVANCED_MATERIALS
		float puddles = 0.0;
		#if REFLECTION_RAIN > 0 && defined OVERWORLD
		NoU = clamp(NoU, 0.0, 1.0);
		
		if (water < 0.5) {
			#if REFLECTION_RAIN == 1
			puddles = GetPuddles(worldPos) * NoU * wetness;
			#else
			puddles = NoU * wetness;
			#endif
		}
		
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
		#endif
		
		float fresnel = pow(clamp(1.0 + dot(newNormal, normalize(viewPos)), 0.0, 1.0), 5.0);

		if (water > 0.5 || (translucent > 0.5 && albedo.a < 0.95)) {
			vec4 reflection = vec4(0.0);
			vec3 skyReflection = vec3(0.0);
	
			fresnel = fresnel * 0.98 + 0.02;
			fresnel*= max(1.0 - isEyeInWater * 0.5 * water, 0.5);
			fresnel*= 1.0 - translucent * 0.3;
			
			#ifdef REFLECTION
			reflection = SimpleReflection(viewPos, newNormal, dither);
			reflection.rgb = pow(reflection.rgb * 2.0, vec3(8.0));
			#endif
			
			if (reflection.a < 1.0) {
				vec3 skyRefPos = reflect(normalize(viewPos), newNormal);
				vec3 specularColor = GetSpecularColor(lightmap.y, 0.0, vec3(1.0));

				#ifdef OVERWORLD
				skyReflection = GetSkyColor(skyRefPos, lightCol, true);
				
				vec3 specular = GetSpecularHighlight(newNormal, normalize(viewPos), lightVec,
				                	 				 0.9, vec3(0.02), specularColor, shadow);
				
				skyReflection += specular / ((4.0 - 3.0 * eBS) * fresnel * albedo.a);

				#ifdef AURORA
				skyReflection += DrawAurora(skyRefPos * 100.0, dither, 12);
				#endif

				#ifdef CLOUDS
				vec4 cloud = DrawCloud(skyRefPos * 100.0, dither, lightCol, ambientCol);
				skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
				#endif

				skyReflection *= (4.0 - 3.0 * eBS) * lightmap.y;
				#endif

				#ifdef NETHER
				skyReflection = netherCol.rgb * 0.04;
				#endif

				#ifdef END
				skyReflection = endCol.rgb * 0.01;
				
				vec3 specular = GetSpecularHighlight(newNormal, normalize(viewPos), lightVec,
				                	 				 0.9, vec3(0.02), specularColor, shadow);
				
				skyReflection += specular / ((4.0 - 3.0 * eBS) * fresnel * albedo.a);
				#endif

				skyReflection *= clamp(1.0 - isEyeInWater, 0.0, 1.0);
			}
			
			reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));
			
			albedo.rgb = mix(albedo.rgb, reflection.rgb, fresnel);
			albedo.a = mix(albedo.a, 1.0, fresnel);
		}else{
			#ifdef ADVANCED_MATERIALS
			skyOcclusion = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);

			vec3 baseReflectance = mix(vec3(f0), rawAlbedo, metalness);
			float so = pow(max(ao * 2.0 - 1.0, 0.0), 2.0);

			#ifdef REFLECTION_SPECULAR
			vec3 fresnel3 = mix(baseReflectance, vec3(1.0), fresnel);
			#if MATERIAL_FORMAT == 0
			if (f0 >= 0.9 && f0 < 1.0) {
				baseReflectance = GetMetalCol(f0);
				fresnel3 = ComplexFresnel(fresnel, f0);
				#ifdef ALBEDO_METAL
				fresnel3 *= rawAlbedo;
				#endif
			}
			#endif
			
			fresnel3 *= so * smoothness * smoothness;

			if (length(fresnel3) > 0.005) {
				vec4 reflection = vec4(0.0);
				vec3 skyReflection = vec3(0.0);
				
				reflection = SimpleReflection(viewPos, newNormal, dither);
				reflection.rgb = pow(reflection.rgb * 2.0, vec3(8.0));

				if (reflection.a < 1.0) {
					#ifdef OVERWORLD
					vec3 skyRefPos = reflect(normalize(viewPos.xyz), newNormal);
					skyReflection = GetSkyColor(skyRefPos, lightCol, true);
					
					#ifdef AURORA
					skyReflection += DrawAurora(skyRefPos * 100.0, dither, 12);
					#endif
					
					#ifdef CLOUDS
					vec4 cloud = DrawCloud(skyRefPos * 100.0, dither, lightCol, ambientCol);
					skyReflection = mix(skyReflection, cloud.rgb, cloud.a);
					#endif

					float NoU = clamp(dot(newNormal, upVec), -1.0, 1.0);
					float NoE = clamp(dot(newNormal, eastVec), -1.0, 1.0);
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
					skyReflection = endCol.rgb * 0.01;
					#endif
				}

				reflection.rgb = max(mix(skyReflection, reflection.rgb, reflection.a), vec3(0.0));

				albedo.rgb = albedo.rgb * (1.0 - fresnel3 * (1.0 - metalness)) +
							 reflection.rgb * fresnel3;
				albedo.a = mix(albedo.a, 1.0, GetLuminance(fresnel3));
			}
			#endif

			#if defined OVERWORLD || defined END
			vec3 specularColor = GetSpecularColor(lightmap.y, metalness, baseReflectance);

			albedo.rgb += GetSpecularHighlight(newNormal, viewPos, lightVec, smoothness, baseReflectance,
										   	   specularColor, shadow * so * vanillaDiffuse);
			#endif
			#endif
		}

		#ifdef FOG
		Fog(albedo.rgb, viewPos);
		#endif
		
		
		

if (water > 0.5) {
    gl_FragData[2] = vec4(getRefraction(viewPos, normalize(normalMap)), 0.1, 1.0);
} else {
    gl_FragData[2] = vec4(0.0,0.0,0.15,0.5);
}

		
		
		
		
	}

    /* DRAWBUFFERS:017 */
    gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(vlAlbedo, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat;
varying float dist;

varying vec2 texCoord, lmCoord;

varying vec3 normal, binormal, tangent;
varying vec3 sunVec, upVec, eastVec;
varying vec3 viewVector;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
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
attribute vec4 at_tangent;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Common Functions//
float WavingWater(vec3 worldPos) {
	float fractY = fract(worldPos.y + cameraPosition.y + 0.005);
		
	#ifdef WAVING_WATER
	float wave = sin(6.28 * (frametime * 0.7 + worldPos.x * 0.14 + worldPos.z * 0.07)) +
				 sin(6.28 * (frametime * 0.5 + worldPos.x * 0.10 + worldPos.z * 0.20));
	if (fractY > 0.01) return wave * 0.0125;
	#endif
	
	return 0.0;
}

//Includes//
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

	normal   = normalize(gl_NormalMatrix * gl_Normal);
	binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
								  
	viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = length(gl_ModelViewMatrix * gl_Vertex);

	#ifdef ADVANCED_MATERIALS
	vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = texCoord - midCoord;

	vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
	vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
	
	vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
	color = gl_Color + vec4(0.0, 0.0, 0.001, 0.0);
	
	mat = 0.0;
	
	if (mc_Entity.x == 10301) mat = 2.0;

	const vec2 sunRotationData = vec2(
		 cos(sunPathRotation * 0.01745329251994),
		-sin(sunPathRotation * 0.01745329251994)
	);
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	if (mc_Entity.x == 10300) {
		position.y += WavingWater(position.xyz) * (lmCoord.y * 0.5 + 0.5);
		mat = 1.0;
	}

    #ifdef WORLD_CURVATURE
	position.y -= WorldCurvature(position.xz);
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	if (mat == 0.0) gl_Position.z -= 0.00001;
	
	#if AA == 2
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif