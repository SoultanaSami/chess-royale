shader_type spatial;
uniform vec4 wood_color : source_color = vec4(0.1,0.055,0.033,1.0);
void fragment() {
	float grain = sin(UV.x*160.0 + sin(UV.y*11.0)*4.0 + sin(UV.y*31.0));
	ALBEDO = wood_color.rgb * (0.75 + grain * 0.23);
	ROUGHNESS = 0.83;
}
