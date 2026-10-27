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
	var grass := ShaderMaterial.new()
	grass.shader = load("res://shaders/battlefield_ground.gdshader")
	var road := grass.duplicate() as ShaderMaterial
	road.set_shader_parameter("road", true)
	var cliff := ShaderMaterial.new()
	cliff.shader = load("res://shaders/cliff.gdshader")
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
		match tile.terrain:
			BattlefieldTileData.Terrain.IMPASSABLE:
				for i in range(3):
					ModelSculptor.box(parent, Vector3(.7 - i * .12, .28, .25), p + Vector3(.12 * i, .2 + i * .24, -.14), rock, Vector3(0,.3,.03*i))
			BattlefieldTileData.Terrain.RESOURCE_NODE:
				for x in [-.33, .33]:
					boulder(parent, p + Vector3(x, .26, -.22), Vector3(.38, .65, .50), rock)
				ModelSculptor.box(parent, Vector3(.44, .48, .12), p + Vector3(0, .28, -.33), dark)
				for x in [-.24, .24]:
					ModelSculptor.box(parent, Vector3(.08, .54, .10), p + Vector3(x, .3, -.2), wood)
				ModelSculptor.box(parent, Vector3(.62, .10, .16), p + Vector3(0, .59, -.22), wood)
				boulder(parent, p + Vector3(0, .68, -.3), Vector3(.7, .3, .48), rock)
				for x in [-.15, .15]:
					ModelSculptor.box(parent, Vector3(.025, .025, .67), p + Vector3(x, .08, .16), wood)
				ModelSculptor.box(parent, Vector3(.28, .17, .24), p + Vector3(.27, .16, .2), wood)
				for i in range(3):
					boulder(parent, p + Vector3(.18 + i * .065, .3, .19), Vector3(.12, .12, .12), ore)
				markers[cell] = objective(parent, p, tile.terrain)
			BattlefieldTileData.Terrain.CASTLE:
				ModelSculptor.box(parent, Vector3(1.0, .15, 1.0), p + Vector3(0, .12, 0), rock)
				for x in [-.36, .36]:
					for z in [-.36, .36]:
						ModelSculptor.cylinder(parent, .16, .20, .9, p + Vector3(x, .57, z), rock, 8)
						for corner in [-1, 1]:
							ModelSculptor.box(parent, Vector3(.12, .18, .30), p + Vector3(x + corner * .11, 1.08, z), rock)
				for x in [-.4, .4]:
					ModelSculptor.box(parent, Vector3(.13, .5, .8), p + Vector3(x, .43, 0), rock)
				ModelSculptor.box(parent, Vector3(.6, .55, .11), p + Vector3(0, .43, .36), rock)
				ModelSculptor.box(parent, Vector3(.23, .37, .13), p + Vector3(0, .33, .39), wood)
				markers[cell] = objective(parent, p, tile.terrain)

		if tile.terrain in [BattlefieldTileData.Terrain.RESOURCE_NODE, BattlefieldTileData.Terrain.CASTLE]:
			var torch := CandleProp.new()
			parent.add_child(torch)
			torch.position = p + Vector3(.46, .1, -.4)
			torch.energy = 2.7
			torch.build(.65, .10, cell.x*32+cell.y, true)
	parent.set_meta("objective_markers", markers)
	var materials: Array[Material] = [grass, road, cliff, water]
	for i in range(surfaces.size()):
		if counts[i] == 0: continue
		var mesh := surfaces[i].commit()
		if mesh != null: ModelSculptor.mesh(parent, mesh, Vector3.ZERO, materials[i])
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
