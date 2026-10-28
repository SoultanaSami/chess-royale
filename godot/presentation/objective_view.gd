class_name ObjectiveView
extends Node3D
## AssetSocket accepts any building PackedScene; footprint/capture rules do not depend on art.
var anchor: Vector2i
var terrain: int
var asset_socket: Node3D
var emblem: Node3D
var flag_material: StandardMaterial3D
var ring_material: ShaderMaterial
var torch: BattleBrazier
var pips: Array[MeshInstance3D] = []
var contested_mark: MeshInstance3D
var value_label: Label3D

func setup(board: BoardState, cell: Vector2i, prefab: PackedScene = null) -> void:
	anchor = cell
	terrain = board.tile_at(cell).terrain
	var cells := board.footprint(cell)
	position = (BoardView.world_position(cells[0],board.rows,board.columns) + BoardView.world_position(cells[-1],board.rows,board.columns)) * .5
	position.y = board.surface_height(cell)
	# Movement is blocked by the footprint. Ground picking intentionally ignores
	# building geometry so the far side of a recruitment/capture ring stays usable.
	asset_socket = Node3D.new()
	asset_socket.name = "AssetSocket"
	add_child(asset_socket)
	if prefab != null:
		var asset := prefab.instantiate() as Node3D
		assert(asset != null, "Building prefab requires a Node3D root")
		asset_socket.add_child(asset)
		fit_asset(asset)
	else:
		build_placeholder()
	flag_material = ModelSculptor.material(VisualTheme.GOLD,.65,.35,.18)
	flag_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ModelSculptor.cylinder(self,.025,.025,2.1,Vector3(-.92,1.05,-.7),flag_material,8)
	ModelSculptor.box(self,Vector3(.40,.42,.04),Vector3(-.70,1.95,-.7),flag_material)
	torch = BattleBrazier.new()
	torch.position = Vector3(.94,0,.65)
	add_child(torch)
	ring_material = BattleDecal.material(Color(.8,.56,.22,.28),2)
	for ring_cell in (board.capture_ring(cell) if terrain == BattlefieldTileData.Terrain.RESOURCE_NODE else []):
		var rune := BattleDecal.create(board,ring_cell,ring_material,.028)
		rune.position = -position
		add_child(rune)
	emblem = Node3D.new()
	emblem.position.y = 2.55 if terrain == BattlefieldTileData.Terrain.CASTLE else 1.95
	add_child(emblem)
	shield(emblem,Vector3(-.38,0,0),flag_material,.65)
	if terrain == BattlefieldTileData.Terrain.CASTLE:
		for i in range(3):
			var mat := ModelSculptor.material(VisualTheme.GOLD,.6,.3,1.2)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			pips.append(shield(emblem,Vector3(-.02+i*.27,0,0),mat,.5))
	else:
		var gold := ModelSculptor.material(Color("ffc459"),.8,.25,.45)
		var coin := ModelSculptor.cylinder(emblem,.13,.13,.045,Vector3(0,0,0),gold,24)
		coin.rotation.x = PI/2
		value_label = Label3D.new()
		value_label.text = "+%d" % board.tile_at(cell).resource_yield
		value_label.font = VisualTheme.serif()
		value_label.font_size = 32
		value_label.pixel_size = .01
		value_label.position = Vector3(.32,0,.01)
		value_label.modulate = Color("ffe0a0")
		value_label.outline_size = 3
		emblem.add_child(value_label)
	var warning := ModelSculptor.material(Color("ff5b3a"),0,.4,2)
	contested_mark = ModelSculptor.box(emblem,Vector3(.08,.3,.05),Vector3(.77,0,0),warning,Vector3(0,0,.3))
	contested_mark.visible = false
	for mesh in asset_socket.find_children("*","MeshInstance3D",true,false):
		mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	update_state(board,false)

func fit_asset(asset: Node3D) -> void:
	var box := AABB()
	var first := true
	var meshes := asset.find_children("*","MeshInstance3D",true,false)
	if asset is MeshInstance3D: meshes.append(asset)
	for mesh in meshes:
		var local: AABB = asset_socket.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	if not first:
		var factor := minf(2.05/maxf(box.size.x,box.size.z),2.15/maxf(.01,box.size.y))
		asset_socket.scale = Vector3.ONE * factor
		asset_socket.position = -Vector3(box.get_center().x,box.position.y,box.get_center().z)*factor

func build_placeholder() -> void:
	var stone := ModelSculptor.material(Color("343d48"),.1,.85)
	var wood := ModelSculptor.material(Color("31251d"),.05,.9)
	var dark := ModelSculptor.material(Color("050609"),0,1)
	var ore := ModelSculptor.material(Color("ffc15c"),.8,.3,.6)
	ModelSculptor.box(asset_socket,Vector3(2.04,.12,2.04),Vector3(0,.06,0),stone)
	if terrain == BattlefieldTileData.Terrain.CASTLE:
		for x in [-.72,.72]:
			for z in [-.72,.72]:
				ModelSculptor.cylinder(asset_socket,.25,.30,1.55,Vector3(x,.86,z),stone,10)
				for sign in [-1,1]:
					ModelSculptor.box(asset_socket,Vector3(.16,.22,.48),Vector3(x+sign*.16,1.72,z),stone)
		for x in [-.76,.76]:
			ModelSculptor.box(asset_socket,Vector3(.16,1,1.4),Vector3(x,.65,0),stone)
		for z in [-.76,.76]:
			ModelSculptor.box(asset_socket,Vector3(1.4,1,.16),Vector3(0,.65,z),stone)
		ModelSculptor.box(asset_socket,Vector3(.5,.75,.18),Vector3(0,.48,.8),wood)
		ModelSculptor.box(asset_socket,Vector3(.65,1.7,.65),Vector3(0,1,0),stone)
	else:
		for x in [-.6,.6]:
			BattlefieldTerrainView.boulder(asset_socket,Vector3(x,.6,-.2),Vector3(.85,1.35,1.1),stone)
		BattlefieldTerrainView.boulder(asset_socket,Vector3(0,1.2,-.3),Vector3(1.6,.65,1.15),stone)
		ModelSculptor.box(asset_socket,Vector3(.94,.93,.1),Vector3(0,.58,.19),dark)
		for x in [-.5,.5]:
			ModelSculptor.box(asset_socket,Vector3(.13,1.12,.16),Vector3(x,.65,.30),wood)
		ModelSculptor.box(asset_socket,Vector3(1.28,.14,.2),Vector3(0,1.22,.3),wood)
		for x in [-.22,.22]:
			ModelSculptor.box(asset_socket,Vector3(.03,.03,.95),Vector3(x,.15,.55),stone)
		ModelSculptor.box(asset_socket,Vector3(.5,.35,.40),Vector3(.61,.30,.65),wood)
		for i in range(4):
			BattlefieldTerrainView.boulder(asset_socket,Vector3(.44+i*.1,.53,.65),Vector3(.18,.18,.20),ore)

static func shield(parent: Node3D, at: Vector3, mat: Material, size: float) -> MeshInstance3D:
	var points := [Vector3(-.3,.35,0),Vector3(.3,.35,0),Vector3(.25,-.15,0),Vector3(0,-.42,0),Vector3(-.25,-.15,0)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,4):
		for index in [0,i,i+1]:
			tool.set_normal(Vector3.BACK)
			tool.add_vertex(points[index]*size)
	return ModelSculptor.mesh(parent,tool.commit(),at,mat)

func update_state(board: BoardState, threatened: bool) -> void:
	var tile := board.tile_at(anchor)
	var color := Color("67b9fa") if tile.owner == 0 else Color("f0674f") if tile.owner == 1 else Color("e9ad50")
	flag_material.albedo_color = color
	flag_material.emission = color
	ring_material.set_shader_parameter("tint",Color(color,.26))
	torch.set_color(color if tile.owner != -1 and terrain == BattlefieldTileData.Terrain.RESOURCE_NODE else Color("ff9d45"))
	contested_mark.visible = threatened or board.ring_teams(anchor).size() > 1
	for i in range(pips.size()):
		var mat := pips[i].material_override as StandardMaterial3D
		mat.albedo_color = color if i < tile.garrison_shields else Color("20252b")
		mat.emission = color
		mat.emission_energy_multiplier = .65 if i < tile.garrison_shields else 0

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and emblem != null:
		emblem.look_at(camera.global_position,Vector3.UP,true)
