extends SceneTree

var checks := 0
var failures := 0

const CLASSIC_FOUNDATIONS := {
	"phalanx": "res://assets/ASSET LIBRARY/Figurine_Foundation/pawn_foundation.glb",
	"cavalry": "res://assets/ASSET LIBRARY/Figurine_Foundation/knight_foundation.glb",
	"assassin": "res://assets/ASSET LIBRARY/Figurine_Foundation/bishop_foundation.glb",
	"ram": "res://assets/ASSET LIBRARY/Figurine_Foundation/rook_3d_mesh.glb",
	"trebuchet": "res://assets/ASSET LIBRARY/Figurine_Foundation/rook_3d_mesh.glb",
	"golem": "res://assets/ASSET LIBRARY/Figurine_Foundation/rook_3d_mesh.glb",
	"queen": "res://assets/ASSET LIBRARY/Figurine_Foundation/queen_3d_mesh.glb",
	"guard": "res://assets/ASSET LIBRARY/Figurine_Foundation/king_foundation.glb",
}

const TACTICAL_FOUNDATIONS := {
	"phalanx": "res://assets/ASSET LIBRARY/Figurine_Foundation/pawn_foundation.glb",
	"cavalry": "res://assets/ASSET LIBRARY/Figurine_Foundation/knight_foundation.glb",
	"assassin": "res://assets/ASSET LIBRARY/Figurine_Foundation/bishop_foundation.glb",
	"ram": "res://assets/ASSET LIBRARY/Figurine_Foundation/rook_3d_mesh.glb",
	"queen": "res://assets/ASSET LIBRARY/Figurine_Foundation/queen_3d_mesh.glb",
}

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

func check_foundation(view: UnitView, expected_path: String, label: String) -> void:
	var foundation := view.foundation
	check(foundation != null, "%s has a foundation" % label)
	if foundation == null:
		return
	check(foundation.scene_file_path == expected_path, "%s uses the correct role foundation" % label)
	check(is_equal_approx(foundation.rotation.y, PI), "%s foundation faces the opposing side" % label)
	var meshes: Array[MeshInstance3D] = []
	collect_meshes(foundation, meshes)
	check(meshes.size() == 1, "%s foundation has one mesh" % label)
	if meshes.size() != 1:
		return
	var bounds := world_bounds(meshes[0])
	var bottom_offset := bounds.position.y - view.position.y
	var top_offset := bounds.end.y - view.position.y
	check(bottom_offset >= -0.01 and bottom_offset <= 0.03, "%s foundation rests on the board" % label)
	check(top_offset >= 0.17 and top_offset <= 0.21, "%s foundation top aligns with the figurine" % label)
	check(bounds.size.x < 1.0 and bounds.size.z < 1.0, "%s foundation fits on its board tile" % label)

func _run() -> void:
	var catalog := Catalog.new()
	var tactical := TacticalCatalog.new()
	var views: Array[UnitView] = []
	var paths: Array[String] = []
	var labels: Array[String] = []
	var uid := 100

	for variant_id in CLASSIC_FOUNDATIONS:
		var piece := catalog.get_piece(variant_id) as PieceVariantData
		check(piece != null, "Classic piece %s loads" % variant_id)
		if piece == null:
			continue
		var view := UnitView.new()
		root.add_child(view)
		view.setup(UnitState.new(uid, piece, 0, Vector2i(7, 1)), catalog)
		views.append(view)
		paths.append(CLASSIC_FOUNDATIONS[variant_id])
		labels.append("Classic %s" % variant_id)
		uid += 1

	for unit_id in TACTICAL_FOUNDATIONS:
		var definition := tactical.get_unit(unit_id)
		check(definition != null, "Tactical unit %s loads" % unit_id)
		if definition == null:
			continue
		var view := UnitView.new()
		root.add_child(view)
		view.setup(UnitState.new(uid, definition, 0, Vector2i(7, 1)))
		views.append(view)
		paths.append(TACTICAL_FOUNDATIONS[unit_id])
		labels.append("Tactical %s" % unit_id)
		uid += 1

	var opposing_piece := catalog.get_piece("phalanx") as PieceVariantData
	check(opposing_piece != null, "Opposing team piece loads")
	if opposing_piece != null:
		var opposing_view := UnitView.new()
		root.add_child(opposing_view)
		opposing_view.setup(UnitState.new(uid, opposing_piece, 1, Vector2i(0, 6)), catalog)
		check(is_equal_approx(opposing_view.foundation.rotation.y, 0.0), "Opposing foundation faces the opposing side")

	await process_frame
	for index in range(views.size()):
		check_foundation(views[index], paths[index], labels[index])

	print("FOUNDATION ASSET: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
