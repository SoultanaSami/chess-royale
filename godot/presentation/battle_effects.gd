class_name BattleEffects
extends RefCounted

static func particles(parent: Node3D, at: Vector3, color: Color, count: int, lifetime: float, one_shot: bool, debris: bool = false) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.amount = count
	emitter.lifetime = lifetime
	emitter.one_shot = one_shot
	emitter.explosiveness = .95 if one_shot else 0
	emitter.position = at
	emitter.visibility_aabb = AABB(Vector3(-3,-2,-3),Vector3(6,6,6))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 75 if one_shot else 18
	process.initial_velocity_min = .8 if one_shot else .35
	process.initial_velocity_max = 2.1 if one_shot else 1.0
	process.gravity = Vector3(0,-4,0) if one_shot else Vector3(0,.1,0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = .13 if one_shot else .04
	process.scale_min = .4
	process.scale_max = 1.2
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	emitter.process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if not one_shot else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.emission_enabled = not one_shot
	material.emission = color
	material.emission_energy_multiplier = 4
	if debris:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * .055
		mesh.material = material
		emitter.draw_pass_1 = mesh
	else:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		var mesh := QuadMesh.new()
		mesh.size = Vector2(.18,.18) if one_shot else Vector2(.045,.09)
		mesh.material = material
		emitter.draw_pass_1 = mesh
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(emitter)
	emitter.emitting = true
	if one_shot:
		emitter.restart()
		parent.get_tree().create_timer(lifetime + .2).timeout.connect(emitter.queue_free)
	return emitter

static func impact(parent: Node3D, board: BoardState, cell: Vector2i) -> void:
	var at := BoardView.world_position(cell,board.rows,board.columns) + Vector3(0,board.surface_height(cell)+.12,0)
	particles(parent,at,Color(.50,.43,.34,.5),24,.6,true)
	particles(parent,at,Color(.36,.32,.27,.9),10,.5,true,true)
	var mat := BattleDecal.material(Color(.95,.67,.28,.7),0)
	var flash := BattleDecal.create(board,cell,mat,.05)
	parent.add_child(flash)
	var tween := parent.create_tween()
	tween.tween_method(func(value: float): mat.set_shader_parameter("strength",value),1.0,0.0,.22)
	tween.tween_callback(flash.queue_free)
