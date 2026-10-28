shader_type spatial;
render_mode cull_disabled;
uniform sampler2D stone_normal : hint_normal, repeat_enable;
uniform sampler2D stone_grain : repeat_enable;
uniform bool is_road = false;
uniform bool is_cliff = false;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec3 weights = pow(abs(normalize(world_normal)), vec3(5.0));
 weights /= max(dot(weights, vec3(1.0)), 0.001);
 vec3 p = world_pos * .58;
 float grain = texture(stone_grain,p.yz).r * weights.x + texture(stone_grain,p.xz).r * weights.y + texture(stone_grain,p.xy).r * weights.z;
 float detail = texture(stone_grain,p.xz*5.2+p.y*.07).r;
 vec3 nx = texture(stone_normal,p.yz).xyz * 2.0 - 1.0;
 vec3 ny = texture(stone_normal,p.xz).xyz * 2.0 - 1.0;
 vec3 nz = texture(stone_normal,p.xy).xyz * 2.0 - 1.0;
 vec3 mapped = vec3(nx.z*sign(world_normal.x),nx.x,nx.y)*weights.x + vec3(ny.x,ny.z*sign(world_normal.y),ny.y)*weights.y + vec3(nz.x,nz.y,nz.z*sign(world_normal.z))*weights.z;
 NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(world_normal,mapped,.5)),0.0)).xyz);
 vec3 slate = mix(vec3(.065,.085,.10),vec3(.235,.25,.26),grain);
 vec3 moss = mix(vec3(.075,.105,.085),vec3(.20,.22,.16),grain);
 vec3 mud = mix(vec3(.10,.075,.055),vec3(.27,.22,.15),grain);
 ALBEDO = (is_road ? mud : mix(slate,moss,weights.y * (is_cliff ? .15 : .55))) * (.82 + detail*.28);
 ROUGHNESS = mix(.48,.9,grain);
 METALLIC = .06;
 SPECULAR = .35;
}
