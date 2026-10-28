class_name BattlefieldConfig
extends Resource
## Editor-authored layout. create_board produces independent, mutable tile state.
@export_range(8, 40) var rows: int = 12
@export_range(8, 40) var columns: int = 16
@export var river_cells: Array[Vector2i] = []
@export var impassable_cells: Array[Vector2i] = []
@export var resource_cells: Array[Vector2i] = []
@export var road_cells: Array[Vector2i] = []
@export var forest_cells: Array[Vector2i] = []
@export var mid_ground: Array[Vector2i] = []
@export var high_ground: Array[Vector2i] = []
@export var ramps_north: Array[Vector2i] = []
@export var ramps_south: Array[Vector2i] = []
@export var player_castle := Vector2i(-1, -1)
@export var enemy_castle := Vector2i(-1, -1)
@export var player_vanguard: Array[Vector2i] = []
@export var enemy_vanguard: Array[Vector2i] = []
@export var high_yield_mines: Array[Vector2i] = []
@export var void_cells: Array[Vector2i] = []
@export var mine_prefab: PackedScene
@export var castle_prefab: PackedScene
@export_range(0, 99) var node_income: int = 1
@export_range(1, 99) var castle_shields: int = 3
@export_range(0, 99) var starting_gold: int = 10
@export_range(0, 99) var base_income: int = 2
@export_range(1, 6) var max_cp: int = 3
## Zero disables the optional turn timer. Pausing the match pauses this clock.
@export_range(0, 300) var turn_time_limit: float = 0

func castle_cell(team: int) -> Vector2i:
	var custom := player_castle if team == 0 else enemy_castle
	if custom != Vector2i(-1, -1):
		return custom
	return Vector2i(rows - 2 if team == 0 else 0, columns / 2)

func validation_error() -> String:
	if rows < 8 or columns < 8 or rows > 40 or columns > 40:
		return "Battlefield dimensions must be between 8 and 40."
	if node_income < 0 or castle_shields < 1 or starting_gold < 0 or base_income < 0 or max_cp < 1 or max_cp > 6 or turn_time_limit < 0:
		return "Invalid objective income or shields."
	var occupied := {castle_cell(0): true, castle_cell(1): true}
	if castle_cell(0) == castle_cell(1):
		return "Castles must be distinct."
	for group in [[castle_cell(0), castle_cell(1)], mid_ground, high_ground, ramps_north, ramps_south, player_vanguard, enemy_vanguard]:
		for cell in group:
			if cell.x < 0 or cell.y < 0 or cell.x >= rows or cell.y >= columns:
				return "Position outside map: %s" % cell
	for cell in mid_ground:
		if cell in high_ground: return "Overlapping elevations."
	for cell in high_yield_mines:
		if cell not in resource_cells: return "High yield needs a gold mine."
	for group in [river_cells, impassable_cells, resource_cells, forest_cells, void_cells]:
		for cell in group:
			if cell.x < 0 or cell.y < 0 or cell.x >= rows or cell.y >= columns:
				return "Terrain cell outside battlefield: %s" % cell
			if occupied.has(cell):
				return "Overlapping terrain/objective at %s" % cell
			occupied[cell] = true
	for cell in road_cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= rows or cell.y >= columns or cell in river_cells or cell in impassable_cells or cell in forest_cells:
			return "Road outside walkable map: %s" % cell
	var structures := {}
	for anchor in resource_cells + [castle_cell(0), castle_cell(1)]:
		var level := 2 if anchor in high_ground else 1 if anchor in mid_ground else 0
		for r in range(2):
			for c in range(2):
				var cell: Vector2i = anchor + Vector2i(r,c)
				if cell.x >= rows or cell.y >= columns or structures.has(cell): return "Building footprints overlap or leave the map."
				if cell in river_cells or cell in impassable_cells or cell in void_cells or cell in forest_cells or cell in ramps_north or cell in ramps_south: return "Buildings require clear, flat ground."
				var height := 2 if cell in high_ground else 1 if cell in mid_ground else 0
				if height != level: return "Building footprint crosses a cliff."
				if cell in player_vanguard or cell in enemy_vanguard: return "Vanguard overlaps a building."
				structures[cell] = anchor
	return ""

func create_board() -> BoardState:
	assert(validation_error().is_empty(), validation_error())
	var board := BoardState.new(rows, columns)
	board.castles = {0: castle_cell(0), 1: castle_cell(1)}
	board.vanguards = {0: player_vanguard.duplicate(), 1: enemy_vanguard.duplicate()}
	for cell in mid_ground: board.tile_at(cell).elevation = 1
	for cell in high_ground: board.tile_at(cell).elevation = 2
	for cell in ramps_north + ramps_south:
		board.tile_at(cell).ramp = true
		board.tile_at(cell).ramp_direction = Vector2i(-1, 0) if cell in ramps_north else Vector2i(1, 0)
	for cell in river_cells:
		board.tile_at(cell).terrain = BattlefieldTileData.Terrain.RIVER
	for cell in void_cells:
		board.tile_at(cell).terrain = BattlefieldTileData.Terrain.VOID
	for cell in impassable_cells:
		board.tile_at(cell).terrain = BattlefieldTileData.Terrain.IMPASSABLE
	for cell in forest_cells:
		board.tile_at(cell).forest = true
	for cell in road_cells:
		board.tile_at(cell).road = true
	for cell in resource_cells:
		var tile := board.tile_at(cell)
		tile.terrain = BattlefieldTileData.Terrain.RESOURCE_NODE
		tile.resource_yield = node_income + (1 if cell in high_yield_mines else 0)
	for side in [0, 1]:
		var tile := board.tile_at(castle_cell(side))
		tile.terrain = BattlefieldTileData.Terrain.CASTLE
		tile.owner = side
		tile.garrison_shields = castle_shields
	for anchor in resource_cells + [castle_cell(0), castle_cell(1)]:
		var cells: Array[Vector2i] = []
		for r in range(2):
			for c in range(2):
				var cell: Vector2i = anchor + Vector2i(r,c)
				cells.append(cell)
				board.tile_at(cell).building_anchor = anchor
		board.buildings[anchor] = cells
	return board
