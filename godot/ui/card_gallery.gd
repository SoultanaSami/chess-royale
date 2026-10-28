class_name CardGallery
extends Node
## One shared render per catalog unit; cards reuse the same live texture.
var textures: Dictionary = {}

func build(catalog: Catalog) -> void:
	for id in catalog.ordered_ids:
		var data := catalog.get_piece(id)
		if data.kind != "unit":
			continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(256, 260)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.msaa_3d = Viewport.MSAA_2X
		add_child(viewport)
		var root := Node3D.new()
		viewport.add_child(root)
		var model: Node3D = load(data.model_asset_path).instantiate()
		root.add_child(model)
		model.rotation.y = -0.4
		ModelSculptor.cylinder(root, 0.45, 0.42, 0.1, Vector3(0, 0, 0), ModelSculptor.material(Color("252d32"), 0.4))
		var environment := WorldEnvironment.new()
		var env := Environment.new()
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("b7c9d8")
		env.ambient_light_energy = 0.65
		environment.environment = env
		root.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -40, 0)
		light.light_energy = 1.9
		root.add_child(light)
		var rim := OmniLight3D.new()
		rim.position = Vector3(-1, 1, -1)
		rim.light_color = Color("ffad61")
		rim.light_energy = 3.5
		root.add_child(rim)
		var camera := Camera3D.new()
		camera.position = Vector3(1.8, 1.65, 3)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.9
		root.add_child(camera)
		camera.look_at(Vector3(0, 0.68, 0))
		textures[id] = viewport.get_texture()

func build_tactical(catalog: TacticalCatalog) -> void:
	for id in catalog.entries:
		var data := catalog.get_unit(id)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(280,350)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.msaa_3d = Viewport.MSAA_2X
		add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		var model := data.mesh_prefab.instantiate() as Node3D
		world.add_child(model)
		model.rotation.y = -.25
		var bounds := AABB()
		var first := true
		var meshes := model.find_children("*","MeshInstance3D",true,false)
		if model is MeshInstance3D: meshes.append(model)
		for mesh in meshes:
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var environment := WorldEnvironment.new()
		var env := Environment.new()
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("abb8d0")
		env.ambient_light_energy = .55
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		environment.environment = env
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35,145,0)
		light.light_energy = 2.0
		world.add_child(light)
		var rim := OmniLight3D.new()
		rim.position = Vector3(-1,1,1)
		rim.light_color = Color("ffb45e")
		rim.light_energy = 4
		world.add_child(rim)
		var camera := Camera3D.new()
		world.add_child(camera)
		var focus := bounds.get_center()
		focus.y = bounds.position.y + bounds.size.y * (.58 if data.chess_role == UnitData.ChessRole.ROOK else .70)
		camera.position = focus + Vector3(1.1,.25,-3)
		camera.look_at(focus)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.size = maxf(.65,bounds.size.y * (.98 if data.chess_role == UnitData.ChessRole.ROOK else .76))
		if data.chess_role == UnitData.ChessRole.ROOK: camera.size = maxf(camera.size,bounds.size.x*1.15)
		textures[str(id)] = viewport.get_texture()
