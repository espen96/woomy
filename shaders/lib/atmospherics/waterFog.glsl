void WaterFog(inout vec3 color, vec3 viewPos) {
    float fog = length(viewPos) / waterFogRange;
    fog = 1.0 - exp(-3.0 * fog * sqrt(fog));
    
    vec3 waterFogColor = waterColor.rgb * waterAlpha * 0.25 * (1.0 - blindFactor);

    #ifdef OVERWORLD
    vec3 waterFogTint = lightCol * eBS * shadowFade + 0.05;
    #endif
    #ifdef NETHER
    vec3 waterFogTint = netherCol.rgb;
    #endif
    #ifdef END
    vec3 waterFogTint = endCol.rgb;
    #endif
    waterFogTint = sqrt(waterFogTint * length(waterFogTint));

    color = mix(color, waterFogColor * waterFogTint, fog);
}