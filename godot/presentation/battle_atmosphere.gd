class_name BattleAtmosphere
extends RefCounted

static func configure(parent: Node3D, env: Environment, moon: DirectionalLight3D, board: BoardState) -> void:
	var high_end := RenderingServer.get_current_rendering_method() == "forward_plus"
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("070b1c")
	atmosphere.sky_horizon_color = Color("493029")
	atmosphere.ground_bottom_color = Color("050713")
	atmosphere.ground_horizon_color = Color("392629")
	atmosphere.sky_curve = .22
	atmosphere.energy_multiplier = .55
	sky.sky_material = atmosphere
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("778397")
	env.ambient_light_energy = .38
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = .9
	env.ssao_enabled = high_end
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.8
	env.ssao_detail = .7
	env.sdfgi_enabled = high_end
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = .3
	env.sdfgi_energy = .7
	env.glow_enabled = true
	env.glow_hdr_threshold = .9
	env.glow_intensity = .55
	env.glow_strength = .8
	env.glow_bloom = .06
	env.volumetric_fog_enabled = high_end
	env.volumetric_fog_density = .02
	env.volumetric_fog_albedo = Color("8799b6")
	env.volumetric_fog_length = 70
	env.volumetric_fog_sky_affect = .35
	env.volumetric_fog_ambient_inject = .5
	env.fog_enabled = not high_end
	env.fog_light_color = Color("28334e")
	env.fog_density = .012
	env.fog_height = 0
	env.fog_height_density = .16
	moon.light_color = Color("c2cee5")
	moon.light_energy = 1.15
	moon.rotation_degrees = Vector3(-38, -32, 0)
	moon.shadow_enabled = true
	moon.shadow_blur = 1.5
	var width := board.columns * BoardView.SPACING
	var depth := board.rows * BoardView.SPACING
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/river.gdshader")
	ModelSculptor.box(parent, Vector3(width + 90,.1,depth + 90), Vector3(0,-3.2,0), water)
	if high_end:
		var canyon := FogVolume.new()
		canyon.size = Vector3(width + 9, 2.8, depth + 9)
		canyon.position.y = -.8
		var fog := FogMaterial.new()
		fog.density = .045
		fog.albedo = Color("5e7498")
		canyon.material = fog
		parent.add_child(canyon)

static func stone_material(road: bool = false, cliff: bool = false) -> ShaderMaterial:
	var noise := FastNoiseLite.new()
	noise.frequency = .035
	noise.fractal_octaves = 5
	noise.fractal_gain = .58
	var normals := NoiseTexture2D.new()
	normals.width = 256
	normals.height = 256
	normals.seamless = true
	normals.as_normal_map = true
	normals.bump_strength = .65
	normals.noise = noise
	var grain := NoiseTexture2D.new()
	grain.width = 256
	grain.height = 256
	grain.seamless = true
	grain.noise = noise
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/triplanar_stone.gdshader")
	material.set_shader_parameter("stone_normal", normals)
	material.set_shader_parameter("stone_grain", grain)
	material.set_shader_parameter("is_road", road)
	material.set_shader_parameter("is_cliff", cliff)
	return material
