shader_type spatial;
render_mode cull_disabled;

varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float ripple = sin(world_pos.x * 8.0 + world_pos.z * 3.0 - TIME * 1.2);
	ALBEDO = mix(vec3(0.035, 0.13, 0.18), vec3(0.075, 0.17, 0.19), ripple * 0.18 + 0.45);
	ROUGHNESS = 0.28;
	METALLIC = 0.35;
}
