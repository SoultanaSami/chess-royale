class_name CandleProp
extends Node3D
## Reusable wax candle: irregular lip, melted pool, drips, wick and animated flame.
var flame_light: OmniLight3D
var phase: float = 0.0
var elapsed: float = 0.0
var energy: float = 1.1

func build(height: float = 0.65, radius: float = 0.105, seed_value: int = 1, lit: bool = true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	phase = rng.randf() * TAU
	var wax := ModelSculptor.material(Color("d3bd8c"), 0.0, 0.56)
	var melted := ModelSculptor.material(Color("aa8551"), 0.0, 0.24)
	var brass := ModelSculptor.material(Color("977344"), 0.78, 0.3)
	var dark := ModelSculptor.material(Color("221c17"), 0.5, 0.54)
	ModelSculptor.cylinder(self, radius*1.9, radius*1.75, 0.045, Vector3(0,0.025,0), brass, 32)
	ModelSculptor.cylinder(self, radius*1.1, radius*0.9, 0.14, Vector3(0,0.11,0), dark, 24)
	ModelSculptor.cylinder(self, radius*1.5, radius*1.5, 0.025, Vector3(0,0.19,0), brass, 32)
	var base := 0.2
	ModelSculptor.cylinder(self, radius, radius*0.95, height, Vector3(0,base+height/2,0), wax, 32)
	# An uneven ring leaves a recessed pool around the charred wick.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(48):
		var a := i*TAU/48.0
		var b := (i+1)*TAU/48.0
		var ha := base+height+sin(a*5.0+phase)*0.012+sin(a*9.0)*0.006
		var hb := base+height+sin(b*5.0+phase)*0.012+sin(b*9.0)*0.006
		var outer_a := Vector3(cos(a)*radius*0.96,ha,sin(a)*radius*0.96)
		var outer_b := Vector3(cos(b)*radius*0.96,hb,sin(b)*radius*0.96)
		var inner_a := Vector3(cos(a)*radius*0.5,base+height-0.02,sin(a)*radius*0.5)
		var inner_b := Vector3(cos(b)*radius*0.5,base+height-0.02,sin(b)*radius*0.5)
		for v in [outer_a,outer_b,inner_a,outer_b,inner_b,inner_a]:
			surface.add_vertex(v)
	surface.generate_normals()
	ModelSculptor.mesh(self,surface.commit(),Vector3.ZERO,wax)
	ModelSculptor.cylinder(self,radius*0.55,radius*0.55,0.008,Vector3(0,base+height-0.023,0),melted,32)
	for i in range(7):
		var a := rng.randf()*TAU
		var length := rng.randf_range(0.04,height*0.65)
		var p := Vector3(cos(a)*radius*0.94,base+height-length/2,sin(a)*radius*0.94)
		var drop := ModelSculptor.orb(self,rng.randf_range(0.014,0.026),p,wax)
		drop.scale.y = length/0.035
		ModelSculptor.orb(self,0.02,p-Vector3(0,length/2-0.015,0),wax)
	for i in range(3):
		var spill := ModelSculptor.orb(self,radius*0.6,Vector3(rng.randf_range(-radius,radius),0.21,rng.randf_range(-radius,radius)),wax)
		spill.scale = Vector3(1.3,0.12,0.8)
	ModelSculptor.cylinder(self,0.008,0.005,0.055,Vector3(0,base+height+0.008,0),ModelSculptor.material(Color("241b13")),8)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34,0.33)
	var flame := ShaderMaterial.new()
	flame.shader = load("res://shaders/candle_flame.gdshader")
	flame.set_shader_parameter("phase",phase)
	var flame_mesh := ModelSculptor.mesh(self,quad,Vector3(0,base+height+0.16,0),flame)
	flame_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if lit:
		flame_light = OmniLight3D.new()
		flame_light.position = Vector3(0,base+height+0.18,0)
		flame_light.light_color = Color("ffc078")
		flame_light.omni_range = 4.0
		flame_light.light_energy = energy
		add_child(flame_light)

func _process(delta: float) -> void:
	elapsed += delta
	if flame_light != null:
		flame_light.light_energy = energy*(1.0+sin(elapsed*5.3+phase)*0.065+sin(elapsed*11.7+phase)*0.025)
