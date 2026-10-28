class_name UnitView
extends Node3D

var uid: int
var variant_id: String = ""
var model: Node3D
var foundation: Node3D
var plate: Label3D
var selection: MeshInstance3D
var move_tween: Tween
var last_cell := Vector2i(-1, -1)
var pick_area: Area3D
var terrain_board: BoardState
var grid_rows: int = 8
var grid_columns: int = 8

const WHITE_BODY_SHADOW := Color("c6cdd3")
const WHITE_BODY_HIGHLIGHT := Color("f5f3ec")
const DARK_BODY_SHADOW := Color("141a21")
const DARK_BODY_HIGHLIGHT := Color("59656f")
const FOUNDATION_PATHS := {
	"PAWN": "res://assets/ASSET LIBRARY/Figurine_Foundation/pawn_foundation.glb",
	"KNIGHT": "res://assets/ASSET LIBRARY/Figurine_Foundation/knight_foundation.glb",
	"BISHOP": "res://assets/ASSET LIBRARY/Figurine_Foundation/bishop_foundation.glb",
	"ROOK": "res://assets/ASSET LIBRARY/Figurine_Foundation/rook_3d_mesh.glb",
	"QUEEN": "res://assets/ASSET LIBRARY/Figurine_Foundation/queen_3d_mesh.glb",
	"KING": "res://assets/ASSET LIBRARY/Figurine_Foundation/king_foundation.glb",
}
const FOUNDATION_SCALE := 0.45
const FOUNDATION_Y_OFFSET := 0.1

func setup(unit: UnitState, catalog: Catalog = null, rows: int = 8, columns: int = 8, ground: BoardState = null) -> void:
	terrain_board = ground
	grid_rows = rows
	grid_columns = columns
	uid = unit.uid
	pick_area = Area3D.new()
	pick_area.collision_layer = 1
	pick_area.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.3
	collider.shape = shape
	collider.position.y = 0.7
	pick_area.add_child(collider)
	add_child(pick_area)
	var team_color := Color("72bbc8") if unit.team == 0 else Color("e16b58")
	var team_ring := TorusMesh.new()
	team_ring.inner_radius = 0.425
	team_ring.outer_radius = 0.445
	team_ring.rings = 32
	team_ring.ring_segments = 8
	ModelSculptor.mesh(self, team_ring, Vector3(0, 0.04, 0), ModelSculptor.material(team_color, 0.3, 0.5, 0.6))
	plate = Label3D.new()
	plate.font_size = 18
	plate.pixel_size = 0.0018
	plate.position = Vector3(0, 0.125, 0.44)
	plate.modulate = Color("211b15")
	plate.outline_size = 0
	add_child(plate)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.46
	ring.outer_radius = 0.49
	ring.rings = 32
	ring.ring_segments = 8
	var rune_material := ModelSculptor.material(Color("ffb947"), 0.2, 0.4, 0.5)
	rune_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection = ModelSculptor.mesh(self, ring, Vector3(0, 0.04, 0), rune_material)
	selection.visible = false
	sync(unit, catalog, false)

func _apply_team_materials(node: Node, team: int) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.material_override is StandardMaterial3D:
			mesh_instance.material_override = _team_material(mesh_instance.material_override as StandardMaterial3D, team)
		elif mesh_instance.material_override == null and mesh_instance.mesh != null:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var source := mesh_instance.get_active_material(surface)
				if source is StandardMaterial3D:
					mesh_instance.set_surface_override_material(surface, _team_material(source as StandardMaterial3D, team))
	for child in node.get_children():
		_apply_team_materials(child, team)

func _team_material(source: StandardMaterial3D, team: int) -> StandardMaterial3D:
	var result := source.duplicate() as StandardMaterial3D
	var color := source.albedo_color
	var is_gold := source.metallic >= 0.5 and color.r > color.g * 1.2 and color.g > color.b * 1.2
	if source.emission_enabled or is_gold:
		return result
	var shade := clampf((color.get_luminance() - 0.08) / 0.68, 0.0, 1.0)
	var body_color := DARK_BODY_SHADOW.lerp(DARK_BODY_HIGHLIGHT, shade) if team == 1 else WHITE_BODY_SHADOW.lerp(WHITE_BODY_HIGHLIGHT, shade)
	body_color.a = color.a
	result.albedo_color = body_color
	if team == 1:
		result.rim_enabled = true
		result.rim = 0.32
		result.rim_tint = 0.15
	return result

func sync(unit: UnitState, catalog: Catalog, animate: bool = true) -> void:
	var data: Resource = unit.definition if unit.definition != null else catalog.get_piece(unit.variant_id)
	pick_area.set_meta("cell", unit.cell)
	if variant_id != unit.variant_id:
		variant_id = unit.variant_id
		if foundation != null:
			remove_child(foundation)
			foundation.queue_free()
		if model != null:
			remove_child(model)
			model.queue_free()
		var role: String = data.chess_type() if data is UnitData else data.base_chess_type
		var foundation_path: String = FOUNDATION_PATHS.get(role, "")
		assert(not foundation_path.is_empty(), "No foundation configured for chess role %s" % role)
		var foundation_scene := load(foundation_path) as PackedScene
		assert(foundation_scene != null, "Foundation must resolve to an imported GLB PackedScene")
		foundation = foundation_scene.instantiate() as Node3D
		assert(foundation != null, "Foundation root must be Node3D")
		foundation.name = "Foundation"
		foundation.scale = Vector3.ONE * FOUNDATION_SCALE
		foundation.position.y = FOUNDATION_Y_OFFSET
		foundation.rotation.y = PI if unit.team == 0 else 0
		add_child(foundation)
		var packed: PackedScene = data.mesh_prefab if data is UnitData else load(data.model_asset_path)
		assert(packed is PackedScene, "modelAssetPath must resolve to an imported GLB or PackedScene")
		model = packed.instantiate()
		_apply_team_materials(model, unit.team)
		model.position.y = 0.19
		model.rotation.y = 0 if unit.team == 0 else PI
		add_child(model)
	var display_name: String = data.unit_name if data is UnitData else data.display_name
	plate.text = display_name.split(" ")[0].to_upper()
	var target := BoardView.world_position(unit.cell, grid_rows, grid_columns)
	if terrain_board != null: target.y += terrain_board.surface_height(unit.cell)
	if unit.cell != last_cell:
		if move_tween != null:
			move_tween.kill()
		if animate:
			move_tween = create_tween()
			move_tween.tween_property(self, "position", target, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			position = target
		last_cell = unit.cell
