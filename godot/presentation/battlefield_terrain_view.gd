class_name BattlefieldTerrainView
extends RefCounted
## Continuous, welded terrain surfaces. Height data drives rendering and ray picking.
static func corners(board: BoardState, cell: Vector2i, offset: float = 0) -> Array[Vector3]:
	var center := BoardView.world_position(cell, board.rows, board.columns)
	var tile := board.tile_at(cell)
	var result: Array[Vector3] = []
	var half := BoardView.SPACING * .5
	for sign in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		var y := tile.elevation * BoardState.LEVEL_HEIGHT
		if tile.ramp: y += (.5 + sign.y * .5 * tile.ramp_direction.x + sign.x * .5 * tile.ramp_direction.y) * BoardState.LEVEL_HEIGHT
		result.append(Vector3(center.x + sign.x * half, y + offset, center.z + sign.y * half))
	return result

static func quad(tool: SurfaceTool, points: Array[Vector3], faces: Array[Vector3]) -> void:
	var normal := (points[2]-points[0]).cross(points[1]-points[0]).normalized()
	for index in [0,1,2,0,2,3]:
		tool.set_normal(normal)
		tool.set_uv(Vector2(points[index].x, points[index].z))
		tool.add_vertex(points[index])
		faces.append(points[index])

static func build(parent: Node3D, board: BoardState) -> void:
	var grass := BattleAtmosphere.stone_material()
	var road := BattleAtmosphere.stone_material(true)
	var cliff := BattleAtmosphere.stone_material(false, true)
	var rock := ModelSculptor.material(Color("424943"), 0, .95)
	var wood := ModelSculptor.material(Color("33281e"), .05, .9)
	var dark := ModelSculptor.material(Color("101719"), 0, 1)
	var ore := ModelSculptor.material(Color("e2b64c"), .8, .34, .16)
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/river.gdshader")
	var surfaces: Array[SurfaceTool] = []
	for i in range(4):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces.append(surface)
	var faces: Array[Vector3] = []
	var counts := [0,0,0,0]
	var markers := {}
	for cell in board.tiles:
		var tile := board.tile_at(cell)
		if tile.terrain == BattlefieldTileData.Terrain.VOID: continue
		var points := corners(board, cell)
		if tile.terrain == BattlefieldTileData.Terrain.RIVER:
			for i in range(points.size()): points[i].y -= .14
		var p := BoardView.world_position(cell, board.rows, board.columns)
		p.y = board.surface_height(cell)
		var surface_index := 3 if tile.terrain == BattlefieldTileData.Terrain.RIVER else 1 if tile.road else 0
		quad(surfaces[surface_index], points, faces)
		counts[surface_index] += 1
		for edge in range(4):
			var next := (edge + 1) % 4
			var offset: Vector2i = [Vector2i(-1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1)][edge]
			var neighbor := board.tile_at(cell + offset)
			var floor_height := -.8 if neighbor == null or neighbor.terrain == BattlefieldTileData.Terrain.VOID else neighbor.elevation * BoardState.LEVEL_HEIGHT - (.14 if neighbor.terrain == BattlefieldTileData.Terrain.RIVER else 0.0)
			if minf(points[edge].y, points[next].y) > floor_height + .01 or tile.ramp:
				var wall: Array[Vector3] = [points[next], points[edge], Vector3(points[edge].x, floor_height, points[edge].z), Vector3(points[next].x, floor_height, points[next].z)]
				quad(surfaces[2], wall, faces)
				counts[2] += 1
		if tile.forest: tree(parent, p + Vector3(.24,0,-.27), 1.0, wood)
		if tile.terrain == BattlefieldTileData.Terrain.IMPASSABLE:
			for i in range(3):
				ModelSculptor.box(parent,Vector3(.7-i*.12,.28,.25),p+Vector3(.12*i,.2+i*.24,-.14),rock,Vector3(0,.3,.03*i))
	for anchor in board.buildings:
		var view := ObjectiveView.new()
		parent.add_child(view)
		var config: BattlefieldConfig = parent.get("battlefield_config")
		var prefab: PackedScene = null
		if config != null:
			prefab = config.castle_prefab if board.tile_at(anchor).terrain == BattlefieldTileData.Terrain.CASTLE else config.mine_prefab
		view.setup(board,anchor,prefab)
		markers[anchor] = view
	parent.set_meta("objective_markers", markers)
	var materials: Array[Material] = [grass, road, cliff, water]
	for i in range(surfaces.size()):
		if counts[i] == 0: continue
		var mesh := surfaces[i].commit()
		if mesh != null:
			var instance := ModelSculptor.mesh(parent,mesh,Vector3.ZERO,materials[i])
			instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("terrain", true)
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(PackedVector3Array(faces))
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

static func boulder(parent: Node3D, at: Vector3, scale: Vector3, mat: Material) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3.ONE
	var instance := ModelSculptor.mesh(parent, mesh, at, mat)
	instance.scale = scale
	instance.rotation.y = at.x * 2 + at.z

static func tree(parent: Node3D, p: Vector3, size: float, wood: Material) -> void:
	ModelSculptor.cylinder(parent, .07 * size, .11 * size, .75 * size, p + Vector3(0, .36 * size, 0), wood, 6)
	var foliage := ModelSculptor.material(Color("182c24"), 0, 1)
	for i in range(3):
		ModelSculptor.cylinder(parent, 0, (.46 - i * .1) * size, .80 * size, p + Vector3(0, (.8 + i * .32) * size, 0), foliage, 7)

static func objective(parent: Node3D, p: Vector3, terrain: int) -> Dictionary:
	var material := ModelSculptor.material(VisualTheme.GOLD, .5, .35, .2)
	var ring := TorusMesh.new()
	ring.inner_radius = .46
	ring.outer_radius = .51
	ring.rings = 24
	ring.ring_segments = 6
	var marker := ModelSculptor.mesh(parent, ring, p + Vector3(0, .10, 0), material)
	ModelSculptor.cylinder(parent, .02, .02, 1.25, p + Vector3(-.44, .68, -.42), material, 6)
	ModelSculptor.box(parent, Vector3(.26, .22, .03), p + Vector3(-.30, 1.16, -.42), material)
	var caption := Label3D.new()
	caption.font = VisualTheme.body()
	caption.font_size = 24
	caption.pixel_size = .008
	caption.outline_size = 6
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.position = p + Vector3(0, 1.5, 0)
	parent.add_child(caption)
	return {"ring": marker, "material": material, "caption": caption, "terrain": terrain}
