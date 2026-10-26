class_name BoardView
extends Node3D

const SPACING := 1.15
var camera: Camera3D
var highlights := Node3D.new()
var check_layer := Node3D.new()
var units: Dictionary = {}
var gold: StandardMaterial3D

static func world_position(cell: Vector2i) -> Vector3:
	return Vector3((cell.y - 3.5) * SPACING, 0.06, (cell.x - 3.5) * SPACING)

func _ready() -> void:
	name = "BoardController"
	gold = ModelSculptor.material(Color("ffb947"), 0.5, 0.35, 0.5)
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	StoneFloor.build(self)
	for i in range(8):
		letter(char(65 + i), Vector3((i - 3.5) * SPACING, 0.04, 5.12))
		letter(str(8 - i), Vector3(-5.1, 0.04, (i - 3.5) * SPACING))
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c1116")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a0a5a3")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("c4c7c2")
	moon.light_energy = 0.9
	moon.rotation_degrees = Vector3(-65, -25, 0)
	moon.shadow_enabled = true
	add_child(moon)
	camera = Camera3D.new()
	camera.position = Vector3(0, 15.9, 13.35)
	camera.fov = 38
	camera.near = 0.1
	add_child(camera)
	camera.look_at(Vector3(0, 0, 1.8))
	camera.current = true
	add_child(highlights)
	add_child(check_layer)

func fit_view(view_size: Vector2,phone: bool) -> void:
	if camera == null or view_size.y <= 0:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 10.6 / clampf(view_size.x/view_size.y,0.5,1.0)
	camera.position = Vector3(0,18,5) if phone else Vector3(0,16,10)
	camera.look_at(Vector3(0,0.15,0))

func letter(value: String, position_3d: Vector3) -> void:
	var label := Label3D.new()
	label.text = value
	label.font = load("res://assets/fonts/cinzel-600.ttf")
	label.font_size = 40
	label.pixel_size = 0.006
	label.modulate = Color("b89b6d")
	label.position = position_3d
	label.rotation.x = -PI / 2
	add_child(label)

func pick(screen_position: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 100, 1)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var picked := get_world_3d().direct_space_state.intersect_ray(query)
	if not picked.is_empty() and picked.collider.has_meta("cell"):
		return picked.collider.get_meta("cell")
	var hit = Plane(Vector3.UP, 0.06).intersects_ray(origin, direction)
	if hit == null:
		return Vector2i(-1, -1)
	var cell := Vector2i(int(floor(hit.z / SPACING + 4.0)), int(floor(hit.x / SPACING + 4.0)))
	return cell if BoardState.inside(cell) else Vector2i(-1, -1)

func sync(game: GameManager, animate: bool = true) -> void:
	var alive := {}
	for unit in game.board.units.values():
		alive[unit.uid] = true
		if not units.has(unit.uid):
			var view := UnitView.new()
			add_child(view)
			view.setup(unit, game.catalog)
			units[unit.uid] = view
		else:
			units[unit.uid].sync(unit, game.catalog, animate)
	for uid in units.keys():
		if not alive.has(uid):
			var dying: UnitView = units[uid]
			units.erase(uid)
			dying.pick_area.collision_layer = 0
			var tween := create_tween()
			tween.tween_property(dying, "scale", Vector3.ONE * 0.01, 0.14)
			tween.tween_callback(dying.queue_free)
	clear_children(check_layer)
	# Separate from move highlights: selection changes never erase check warnings.
	for side in [0, 1]:
		var king := game.board.king(side)
		if king != null and game.in_check(side):
			var danger := ModelSculptor.material(Color("ff665b"), 0, 0.5, 0.7)
			danger.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rune_frame(check_layer, king.cell, danger)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.44
			ring.outer_radius = 0.52
			ring.rings = 32
			ring.ring_segments = 8
			ModelSculptor.mesh(check_layer, ring, world_position(king.cell) + Vector3(0,0.09,0), danger)
			var marker := Label3D.new()
			marker.text = "!"
			marker.font = load("res://assets/fonts/inter-400.ttf")
			marker.font_size = 56
			marker.pixel_size = 0.012
			marker.modulate = Color("ffb4a0")
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.no_depth_test = true
			marker.outline_size = 10
			marker.position = world_position(king.cell) + Vector3(0, 1.95, 0)
			check_layer.add_child(marker)

func select(cell: Vector2i, targets: Array[Vector2i], path_target := Vector2i(-1, -1)) -> void:
	for unit in units.values():
		unit.selection.visible = unit.last_cell == cell
	clear_children(highlights)
	for target in targets:
		rune_frame(highlights, target, gold)
	if BoardState.inside(path_target) and BoardState.inside(cell):
		var start := world_position(cell) + Vector3(0, 0.08, 0)
		var end := world_position(path_target) + Vector3(0, 0.08, 0)
		var line := ModelSculptor.box(highlights, Vector3(0.024, 0.022, start.distance_to(end)), (start + end) * 0.5, gold)
		line.look_at(end, Vector3.UP)

func rune_frame(parent: Node3D, cell: Vector2i, mat: Material) -> void:
	var p := world_position(cell) + Vector3(0, 0.025, 0)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			ModelSculptor.box(parent, Vector3(0.22, 0.022, 0.025), p + Vector3(x * 0.39, 0, z * 0.49), mat)
			ModelSculptor.box(parent, Vector3(0.025, 0.022, 0.22), p + Vector3(x * 0.49, 0, z * 0.39), mat)
	var rune := ModelSculptor.box(parent, Vector3(0.10, 0.025, 0.10), p + Vector3(0, 0, 0.44), mat)
	rune.rotation.y = PI / 4

func flash_event(event: Dictionary) -> void:
	if event.kind == "capture" and units.has(event.uid):
		var model: Node3D = units[event.uid].model
		var direction := (world_position(event.to) - world_position(event.from)).normalized()
		var rest := Vector3(0, 0.19, 0)
		var tween := create_tween()
		tween.tween_property(model, "position", rest + direction * 0.12, 0.05)
		tween.tween_property(model, "position", rest, 0.07)

func reset() -> void:
	for unit in units.values():
		unit.queue_free()
	units.clear()
	clear_children(highlights)
	clear_children(check_layer)

func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
