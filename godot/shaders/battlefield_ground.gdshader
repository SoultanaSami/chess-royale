shader_type spatial;
render_mode cull_disabled;
uniform bool road = false;
varying vec3 world;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float broad=noise(world.xz*.22), fine=noise(world.xz*13.0);
 vec3 grass=mix(vec3(.105,.13,.105),vec3(.23,.24,.20),broad);
 vec3 gravel=mix(vec3(.16,.145,.12),vec3(.28,.255,.21),broad);
 ALBEDO=(road ? gravel : grass) * (.86+fine*.24);
 ROUGHNESS=.94;
}
