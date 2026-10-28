class_name BattleBrazier
extends Node3D
var light: OmniLight3D
var fire: GPUParticles3D
var color := Color("ff9d45")
var phase: float = 0
func _ready() -> void:
	phase = float(get_instance_id() % 100)
	var iron := ModelSculptor.material(Color("25232b"),.75,.5)
	ModelSculptor.cylinder(self,.05,.10,.62,Vector3(0,.31,0),iron,8)
	ModelSculptor.cylinder(self,.18,.10,.18,Vector3(0,.65,0),iron,8)
	light = OmniLight3D.new()
	light.position.y = .91
	light.light_color = color
	light.light_energy = 3.4
	light.omni_range = 5.5
	light.shadow_enabled = true
	light.shadow_blur = 1.5
	add_child(light)
	fire = BattleEffects.particles(self,Vector3(0,.78,0),color,34,1.3,false)
func set_color(value: Color) -> void:
	if color == value: return
	color = value
	if light != null:
		light.light_color = value
		var process := fire.process_material as ParticleProcessMaterial
		var ramp := process.color_ramp as GradientTexture1D
		ramp.gradient.set_color(0,value)
		ramp.gradient.set_color(1,Color(value,0))
		fire.draw_pass_1.material.emission = value
func _process(_delta: float) -> void:
	if light != null:
		var time := Time.get_ticks_msec() * .001
		light.light_energy = 3.3 + .22*sin(time*8.1+phase) + .12*sin(time*13.7+phase*2)
