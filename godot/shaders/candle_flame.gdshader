shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float phase = 0.0;
void vertex() {
	// A camera-facing flame with a wandering tip, anchored to the wick.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float tip = clamp(UV.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * 5.1 + phase) * 0.018 * (1.0-tip)*(1.0-tip);
}
void fragment() {
	vec2 p = vec2((UV.x-0.5)*2.0, 1.0-UV.y);
	float sway = sin(TIME*6.3+phase+p.y*5.0)*0.035*p.y;
	float width = 0.26 * pow(max(0.0, sin(p.y*3.14159)), 0.8) * (1.1-p.y*0.55);
	float body = 1.0-smoothstep(width*0.65, width+0.025, abs(p.x-sway));
	float core = 1.0-smoothstep(width*0.1, width*0.6, abs(p.x-sway));
	float end = smoothstep(0.0,0.1,p.y)*(1.0-smoothstep(0.88,1.0,p.y));
	float halo = exp(-length(vec2(p.x*2.8,(p.y-0.35)*1.5))*8.0)*0.17;
	vec3 color = mix(vec3(1.0,0.30,0.035),vec3(1.0,0.88,0.42),core);
	color = mix(color,vec3(0.20,0.35,0.75),smoothstep(0.14,0.0,p.y)*0.5);
	ALBEDO = color;
	EMISSION = color * 0.7;
	ALPHA = max(body*end,halo);
}
