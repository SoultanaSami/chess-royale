shader_type canvas_item;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec2 uv = UV;
	float grain = sin(uv.y*850.0 + sin(uv.x*34.0)*3.0 + sin(uv.x*83.0)*0.5);
	float boards = smoothstep(0.0, 0.025, fract(uv.y*8.0));
	float candle = exp(-length((uv-vec2(0.05,0.28))*vec2(2.0,1.0))*7.0) + exp(-length((uv-vec2(0.95,0.28))*vec2(2.0,1.0))*7.0);
	vec3 wood = vec3(0.065,0.051,0.040)*(0.83+grain*0.14+hash(floor(uv*1500.0))*0.08)*mix(0.5,1.0,boards);
	vec3 warm = vec3(0.34,0.15,0.035)*candle;
	float vignette = 1.0 - length((uv-0.5)*0.7);
	COLOR = vec4((wood+warm)*vignette, 0.96);
}
