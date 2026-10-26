shader_type spatial;
render_mode diffuse_burley;
uniform vec4 stone_color : source_color = vec4(0.28,0.28,0.25,1.0);
uniform float tile_seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float scratch(vec2 p, vec2 a, vec2 b, float width) {
	vec2 v=b-a; float t=clamp(dot(p-a,v)/dot(v,v),0.0,1.0);
	return (1.0-smoothstep(width,width+max(width,fwidth(p.x)*0.65),length(p-a-v*t)))*sin(t*3.14159);
}
void fragment() {
	vec2 p=UV; vec2 seeded=p+vec2(tile_seed*7.31,tile_seed*2.17);
	float cloud=noise(seeded*4.0)*0.5+noise(seeded*15.0)*0.3+noise(seeded*65.0)*0.2;
	float edge=min(min(p.x,1.0-p.x),min(p.y,1.0-p.y));
	float bevel=smoothstep(0.0,0.032,edge);
	float pits=smoothstep(0.8,0.96,noise(seeded*120.0));
	float marks=0.0;
	for (int i=0;i<3;i++) {
		float s=tile_seed+float(i)*23.0;
		vec2 a=vec2(hash(vec2(s,3.0)),hash(vec2(9.0,s)))*0.7+0.15;
		vec2 b=a+vec2(0.05+hash(vec2(s,5.0))*0.16,0.03+hash(vec2(s,8.0))*0.04);
		marks+=scratch(p,a,b,0.0012)*step(0.4,hash(vec2(s,17.0)));
	}
	float worn=smoothstep(0.08,0.35,edge);
	ALBEDO=stone_color.rgb*(0.9+cloud*0.2)*mix(0.7,1.0,bevel);
	ALBEDO=mix(ALBEDO,ALBEDO*0.55,min(marks*0.45+pits*0.12,0.5));
	ROUGHNESS=clamp(0.61-worn*0.19+cloud*0.12+marks*0.15,0.32,0.85);
	METALLIC=0.04;
	SPECULAR=0.48;
	NORMAL_MAP=normalize(vec3((noise(seeded*60.0)-0.5)*0.13,(noise(seeded*60.0+0.13)-0.5)*0.13,1.0))*0.5+0.5;
	NORMAL_MAP_DEPTH=0.3;
}
