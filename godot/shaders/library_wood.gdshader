shader_type spatial;
uniform vec4 tint : source_color = vec4(0.12,0.065,0.032,1.0);
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	float grain = sin(UV.x*135.0+sin(UV.y*7.0)*2.5+sin(UV.y*21.0)*0.7);
	float fine = hash(floor(UV*400.0));
	ALBEDO = tint.rgb*(0.85+grain*0.13+fine*0.12);
	ROUGHNESS = 0.42+fine*0.18;
	SPECULAR = 0.35;
}
