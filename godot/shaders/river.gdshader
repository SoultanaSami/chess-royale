shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float wave=sin(world_pos.x*.7+sin(world_pos.z*.4)-TIME*.3);
 ALBEDO=mix(vec3(.007,.014,.022),vec3(.014,.027,.035),wave*.2+.4);
 vec3 n=normalize(vec3(.026*cos(world_pos.x*.7-TIME*.3),1.0,.025*sin(world_pos.z*.8+TIME*.2)));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 ROUGHNESS=.2;
 METALLIC=.05;
 SPECULAR=.65;
}
