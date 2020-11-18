void DepthOutline(inout float z) {
	float ph = 1.0 / 1080.0;
	float pw = ph / aspectRatio;
	for(int i = 0; i < 24; i++) {
		vec2 offset = vec2(pw, ph) * outlineOffsets[i];
		z = min(z, texture2D(depthtex1, texCoord + offset).r);
	}
}