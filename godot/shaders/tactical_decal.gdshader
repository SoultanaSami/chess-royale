shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(.1,.65,1.0,.45);
uniform int pattern = 0; // move, attack, selection/capture rune, ghost
uniform float strength = 1.0;
void fragment() {
 vec2 p = abs(UV-.5);
 float edge = max(p.x,p.y);
 float border = smoothstep(.39,.42,edge) * (1.0-smoothstep(.445,.465,edge));
 float pulse = .80 + .20*sin(TIME*3.5);
 float fill = (1.0-smoothstep(.1,.46,edge))*.25;
 float symbol = 0.0;
 if(pattern==1) {
   symbol = (1.0-smoothstep(.014,.035,abs(p.x-p.y))) * (1.0-smoothstep(.16,.25,edge));
   fill += (1.0-smoothstep(.25,.46,edge))*.30;
 }
 if(pattern==2) {
   float radius=length(UV-.5);
   border=smoothstep(.34,.36,radius)*(1.0-smoothstep(.39,.41,radius));
   symbol=step(.35,radius)*step(radius,.43)*step(.89,abs(sin(atan(UV.y-.5,UV.x-.5)*8.0)));
   fill=0.0;
 }
 float intensity = border + fill + symbol;
 ALBEDO = tint.rgb;
 EMISSION = tint.rgb * (border*2.8 + symbol*3.0 + fill*.35) * pulse * strength;
 ALPHA = clamp(intensity * tint.a * pulse * strength, 0.0, .9);
}
