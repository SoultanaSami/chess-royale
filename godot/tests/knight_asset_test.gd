extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)

func collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		collect_meshes(child, meshes)

func world_bounds(mesh: MeshInstance3D) -> AABB:
	var local := mesh.get_aabb()
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x in [local.position.x, local.end.x]:
		for y in [local.position.y, local.end.y]:
			for z in [local.position.z, local.end.z]:
				var point: Vector3 = mesh.global_transform * Vector3(x, y, z)
				min_corner = Vector3(minf(min_corner.x, point.x), minf(min_corner.y, point.y), minf(min_corner.z, point.z))
				max_corner = Vector3(maxf(max_corner.x, point.x), maxf(max_corner.y, point.y), maxf(max_corner.z, point.z))
	return AABB(min_corner, max_corner - min_corner)

func _run() -> void:
	var catalog := Catalog.new()
	var knight := catalog.get_piece("cavalry") as PieceVariantData
	check(knight != null, "Legacy cavalry Knight variant still loads")
	if knight == null:
		_finish()
		return
	check(knight.id == "cavalry" and knight.base_chess_type == "KNIGHT", "Classic Knight keeps its saved-deck ID and role")
	check(knight.display_name == "Hellknight", "Classic display name is Hellknight")
	check(Catalog.DEFAULT_DECK.count("cavalry") == 2, "Default classic deck retains both cavalry slots")
	check(knight.model_asset_path == "res://assets/models/hellknight.tscn", "Classic catalog maps cavalry to the wrapper")

	var packed := load(knight.model_asset_path) as PackedScene
	check(packed != null, "Hellknight wrapper loads")
	if packed == null:
		_finish()
		return
	var wrapper := packed.instantiate()
	root.add_child(wrapper)
	await process_frame
	var meshes: Array[MeshInstance3D] = []
	collect_meshes(wrapper, meshes)
	check(meshes.size() == 1, "Wrapper contains one authored mesh")
	if meshes.size() != 1:
		_finish()
		return
	var mesh := meshes[0]
	var bounds := world_bounds(mesh)
	check(bounds.position.y >= -0.003 and bounds.position.y <= 0.003, "Scaled boot sole meets wrapper ground origin")
	check(bounds.size.x < 1.15 and bounds.size.z < 1.15, "Scaled footprint fits the 1.15 m board tile")
	check(mesh.mesh.get_surface_count() == 1, "Authored model remains a single material surface")
	var triangle_count := 0
	for surface in range(mesh.mesh.get_surface_count()):
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var indices = arrays[Mesh.ARRAY_INDEX]
		triangle_count += indices.size() / 3
	check(triangle_count < 12000, "Removed plinth brings mesh below the exceptional triangle ceiling")

	var source := mesh.get_active_material(0) as StandardMaterial3D
	check(source != null and source.albedo_texture != null and source.normal_texture != null, "Imported PBR albedo and normal maps remain attached")
	var tactical := TacticalCatalog.new()
	var tactical_cavalry := tactical.get_unit("cavalry")	
	var vanguard := tactical.get_unit("vanguard")
	check(tactical_cavalry != null and tactical_cavalry.unit_name == "Hellknight", "Tactical cavalry keeps ID and adopts the Hellknight name")
	check(tactical_cavalry != null and tactical_cavalry.mesh_prefab.resource_path == "res://assets/models/hellknight.tscn", "Tactical cavalry uses the Hellknight wrapper")
	check(vanguard != null and vanguard.mesh_prefab.resource_path == "res://assets/models/hellknight.tscn", "Tactical vanguard Knight uses the Hellknight wrapper")

	if source != null:
		var white_view := UnitView.new()
		var black_view := UnitView.new()
		root.add_child(white_view)
		root.add_child(black_view)
		white_view.setup(UnitState.new(1, knight, 0, Vector2i(7, 1)), catalog)
		black_view.setup(UnitState.new(2, knight, 1, Vector2i(7, 2)), catalog)
		var white_meshes: Array[MeshInstance3D] = []
		var black_meshes: Array[MeshInstance3D] = []
		collect_meshes(white_view.model, white_meshes)
		collect_meshes(black_view.model, black_meshes)
		var white_material := white_meshes[0].get_active_material(0) as StandardMaterial3D if not white_meshes.is_empty() else null
		var black_material := black_meshes[0].get_active_material(0) as StandardMaterial3D if not black_meshes.is_empty() else null
		check(white_material != null and black_material != null and white_material.albedo_color != black_material.albedo_color, "Existing white/black team tint remains distinct")
		check(white_material != null and black_material != null and white_material.albedo_texture == source.albedo_texture and black_material.albedo_texture == source.albedo_texture, "Team tint preserves the authored albedo texture")

	_finish()

func _finish() -> void:
	print("KNIGHT ASSET: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
