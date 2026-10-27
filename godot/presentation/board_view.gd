class_name BoardView
extends Node3D

const SPACING := 1.15
var grid_rows: int = 8
var grid_columns: int = 8
var terrain_board: BoardState
var camera: Camera3D
var highlights := Node3D.new()
var check_layer := Node3D.new()
var units: Dictionary = {}
var gold: StandardMaterial3D

static func world_position(cell: Vector2i, rows: int = 8, columns: int = 8) -> Vector3:
	return Vector3((cell.y - (columns - 1) * 0.5) * SPACING, 0.06, (cell.x - (rows - 1) * 0.5) * SPACING)

func cell_position(cell: Vector2i) -> Vector3:
	var result := world_position(cell, grid_rows, grid_columns)
	if terrain_board != null: result.y += terrain_board.surface_height(cell)
	return result

func contains_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_rows and cell.y >= 0 and cell.y < grid_columns

func _ready() -> void:
	name = "BoardController"
	gold = ModelSculptor.material(Color("ffb947"), 0.5, 0.35, 0.5)
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if terrain_board != null:
		grid_rows = terrain_board.rows
		grid_columns = terrain_board.columns
	StoneFloor.build(self, terrain_board)
	if terrain_board == null:
		for col in range(grid_columns):
			letter(char(65 + col) if grid_columns <= 26 else str(col + 1), Vector3((col - (grid_columns - 1) * 0.5) * SPACING, 0.04, grid_rows * SPACING * 0.5 + 0.5))
		for row in range(grid_rows):
			letter(str(grid_rows - row), Vector3(-grid_columns * SPACING * 0.5 - 0.5, 0.04, (row - (grid_rows - 1) * 0.5) * SPACING))
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c1116")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a0a5a3")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if terrain_board != null:
		var sky := Sky.new()
		var atmosphere := ProceduralSkyMaterial.new()
		atmosphere.sky_top_color = Color("16212a")
		atmosphere.sky_horizon_color = Color("46545a")
		atmosphere.ground_bottom_color = Color("30392c")
		sky.sky_material = atmosphere
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_energy = .32
		env.fog_enabled = true
		env.fog_light_color = Color("34454b")
		env.fog_density = .006
		env.fog_height = .8
		env.fog_height_density = .09

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
	camera.size = maxf(grid_rows * SPACING + 1.4, (grid_columns * SPACING + 1.4) / maxf(0.2, view_size.x/view_size.y))
	if terrain_board == null:
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
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 500, 3)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var picked := get_world_3d().direct_space_state.intersect_ray(query)
	if not picked.is_empty() and picked.collider.has_meta("cell"):
		return picked.collider.get_meta("cell")
	var hit = picked.position if not picked.is_empty() else Plane(Vector3.UP, 0.06).intersects_ray(origin, direction)
	if terrain_board != null and picked.is_empty(): return BoardState.NONE
	if hit == null:
		return Vector2i(-1, -1)
	var cell := Vector2i(int(floor(hit.z / SPACING + grid_rows * 0.5)), int(floor(hit.x / SPACING + grid_columns * 0.5)))
	return cell if contains_cell(cell) else Vector2i(-1, -1)

func sync_board(board: BoardState, catalog: Catalog = null, animate: bool = true) -> void:
	var alive := {}
	for unit in board.units.values():
		alive[unit.uid] = true
		if not units.has(unit.uid):
			var view := UnitView.new()
			add_child(view)
			view.setup(unit, catalog, grid_rows, grid_columns, terrain_board)
			units[unit.uid] = view
		else:
			units[unit.uid].sync(unit, catalog, animate)
	for uid in units.keys():
		if not alive.has(uid):
			var dying: UnitView = units[uid]
			units.erase(uid)
			dying.pick_area.collision_layer = 0
			var tween := create_tween()
			tween.tween_property(dying, "scale", Vector3.ONE * 0.01, 0.14)
			tween.tween_callback(dying.queue_free)

func sync(game: GameManager, animate: bool = true) -> void:
	sync_board(game.board, game.catalog, animate)
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
			ModelSculptor.mesh(check_layer, ring, cell_position(king.cell) + Vector3(0,0.09,0), danger)
			var marker := Label3D.new()
			marker.text = "!"
			marker.font = load("res://assets/fonts/inter-400.ttf")
			marker.font_size = 56
			marker.pixel_size = 0.012
			marker.modulate = Color("ffb4a0")
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.no_depth_test = true
			marker.outline_size = 10
			marker.position = cell_position(king.cell) + Vector3(0, 1.95, 0)
			check_layer.add_child(marker)

func select(cell: Vector2i, targets: Array[Vector2i], path_target := Vector2i(-1, -1)) -> void:
	for unit in units.values():
		unit.selection.visible = unit.last_cell == cell
	clear_children(highlights)
	for target in targets:
		rune_frame(highlights, target, gold)
	if contains_cell(path_target) and contains_cell(cell):
		var start := cell_position(cell) + Vector3(0, 0.08, 0)
		var end := cell_position(path_target) + Vector3(0, 0.08, 0)
		var line := ModelSculptor.box(highlights, Vector3(0.024, 0.022, start.distance_to(end)), (start + end) * 0.5, gold)
		line.look_at(end, Vector3.UP)

func rune_frame(parent: Node3D, cell: Vector2i, mat: Material) -> void:
	var p := cell_position(cell) + Vector3(0, 0.025, 0)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			ModelSculptor.box(parent, Vector3(0.22, 0.022, 0.025), p + Vector3(x * 0.39, 0, z * 0.49), mat)
			ModelSculptor.box(parent, Vector3(0.025, 0.022, 0.22), p + Vector3(x * 0.49, 0, z * 0.39), mat)
	var rune := ModelSculptor.box(parent, Vector3(0.10, 0.025, 0.10), p + Vector3(0, 0, 0.44), mat)
	rune.rotation.y = PI / 4

func flash_event(event: Dictionary) -> void:
	if event.kind == "capture" and units.has(event.uid):
		var model: Node3D = units[event.uid].model
		var direction := (cell_position(event.to) - cell_position(event.from)).normalized()
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

func sync_objectives(board: BoardState, siege: Array[bool]) -> void:
	clear_children(check_layer)
	var markers: Dictionary = get_meta("objective_markers", {})
	for cell in markers:
		var marker: Dictionary = markers[cell]
		var tile := board.tile_at(cell)
		var color := Color("72bbc8") if tile.owner == 0 else Color("e16b58") if tile.owner == 1 else VisualTheme.GOLD
		marker.material.albedo_color = color
		marker.material.emission = color
		marker.caption.modulate = color
		if tile.terrain == BattlefieldTileData.Terrain.RESOURCE_NODE:
			marker.caption.text = "GOLDMINE +%d · %s" % [tile.resource_yield, "DEINE" if tile.owner == 0 else "GEGNER" if tile.owner == 1 else "NEUTRAL"]
		else:
			var threatened: bool = tile.owner in [0, 1] and siege[tile.owner]
			marker.caption.text = ("! BELAGERT · " if threatened else "BURG · ") + str(tile.garrison_shields)
			if threatened:
				var danger := ModelSculptor.material(Color("ff5144"), 0, .5, .7)
				danger.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				rune_frame(check_layer, cell, danger)
				marker.caption.modulate = Color("ff6755")

func projectile(from: Vector2i, to: Vector2i) -> void:
	var fire := ModelSculptor.material(Color("ffb84f"), .1, .3, 2)
	var ball := SphereMesh.new()
	ball.radius = .10
	ball.height = .2
	var shot := ModelSculptor.mesh(self, ball, cell_position(from) + Vector3(0, .75, 0), fire)
	var tween := create_tween()
	tween.tween_property(shot, "position", cell_position(to) + Vector3(0, .5, 0), .2)
	tween.tween_callback(shot.queue_free)

func select_tactical(cell: Vector2i, destinations: Array[Vector2i], attacks: Array[Vector2i], hovered: Vector2i = BoardState.NONE) -> void:
	for unit in units.values(): unit.selection.visible = unit.last_cell == cell
	clear_children(highlights)
	var shown := {}
	for target in destinations:
		if target not in attacks:
			tactical_overlay(target, Color(.16,.53,.95,.33))
			shown[target] = true
	for target in attacks:
		tactical_overlay(target, Color(.95,.16,.13,.40))
		shown[target] = true
	if terrain_board == null: return
	if terrain_board.contains(hovered):
		for row in range(hovered.x-1, hovered.x+2):
			for col in range(hovered.y-1, hovered.y+2):
				var at := Vector2i(row,col)
				if terrain_board.is_walkable(at) and not shown.has(at):
					tactical_overlay(at, Color(.65,.72,.72,.07))
	if terrain_board.contains(cell): tactical_overlay(cell, Color(1,.78,.30,.23))

func tactical_overlay(cell: Vector2i, color: Color) -> void:
	if terrain_board == null or not terrain_board.contains(cell): return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unused: Array[Vector3] = []
	var points := BattlefieldTerrainView.corners(terrain_board, cell, .035)
	BattlefieldTerrainView.quad(surface, points, unused)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ModelSculptor.mesh(highlights, surface.commit(), Vector3.ZERO, material)
	var edge := ImmediateMesh.new()
	edge.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(4):
		edge.surface_add_vertex(points[i] + Vector3(0,.005,0))
		edge.surface_add_vertex(points[(i+1)%4] + Vector3(0,.005,0))
	edge.surface_end()
	var border := material.duplicate() as StandardMaterial3D
	border.albedo_color.a = minf(.7, color.a * 2)
	ModelSculptor.mesh(highlights, edge, Vector3.ZERO, border)
