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
