class_name UnitView
extends Node3D

var uid: int
var variant_id: String = ""
var model: Node3D
var plate: Label3D
var selection: MeshInstance3D
var move_tween: Tween
var last_cell := Vector2i(-1, -1)
var pick_area: Area3D

func setup(unit: UnitState, catalog: Catalog) -> void:
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
	var stone := ModelSculptor.material(Color("20272b"), 0.2, 0.85)
	var bronze := ModelSculptor.material(Color("ab8350"), 0.75, 0.35)
	ModelSculptor.cylinder(self, 0.41, 0.43, 0.12, Vector3(0, 0.08, 0), stone, 24)
	ModelSculptor.cylinder(self, 0.43, 0.4, 0.045, Vector3(0, 0.16, 0), bronze, 24)
	var team_color := Color("72bbc8") if unit.team == 0 else Color("e16b58")
	ModelSculptor.cylinder(self, 0.435, 0.435, 0.022, Vector3(0, 0.07, 0), ModelSculptor.material(team_color, 0.3, 0.5, 0.6), 24)
	ModelSculptor.box(self, Vector3(0.48, 0.10, 0.04), Vector3(0, 0.12, 0.39), bronze)
	plate = Label3D.new()
	plate.font_size = 18
	plate.pixel_size = 0.0018
	plate.position = Vector3(0, 0.125, 0.415)
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

func sync(unit: UnitState, catalog: Catalog, animate: bool = true) -> void:
	var data := catalog.get_piece(unit.variant_id)
	pick_area.set_meta("cell", unit.cell)
	if variant_id != unit.variant_id:
		variant_id = unit.variant_id
		if model != null:
			model.queue_free()
		var packed = load(data.model_asset_path)
		assert(packed is PackedScene, "modelAssetPath must resolve to an imported GLB or PackedScene")
		model = packed.instantiate()
		model.position.y = 0.19
		model.rotation.y = 0 if unit.team == 0 else PI
		add_child(model)
	plate.text = data.display_name.split(" ")[0].to_upper()
	var target := BoardView.world_position(unit.cell)
	if unit.cell != last_cell:
		if move_tween != null:
			move_tween.kill()
		if animate:
			move_tween = create_tween()
			move_tween.tween_property(self, "position", target, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			position = target
		last_cell = unit.cell
