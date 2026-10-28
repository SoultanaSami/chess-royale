class_name BoardState
extends RefCounted
## Coordinates remain (row, column). Defaults preserve the legacy chess match.
const NONE := Vector2i(-1, -1)
var rows: int
var columns: int
var tiles: Dictionary = {}
var castles: Dictionary = {}
var vanguards: Dictionary = {}
## Anchor -> footprint cells. Objective state is stored only on the anchor tile.
var buildings: Dictionary = {}
const LEVEL_HEIGHT := 1.6

func surface_height(cell: Vector2i) -> float:
	var tile := tile_at(cell)
	return (tile.elevation + (.5 if tile.ramp else 0.0)) * LEVEL_HEIGHT if tile != null else 0.0
var units: Dictionary = {}
var next_uid: int = 1
var en_passant_target := NONE
var en_passant_pawn := NONE

func _init(row_count: int = 8, column_count: int = 8, create_tiles: bool = true) -> void:
	assert(row_count > 0 and column_count > 0)
	rows = row_count
	columns = column_count
	if not create_tiles:
		return
	for row in range(rows):
		for col in range(columns):
			tiles[Vector2i(row, col)] = BattlefieldTileData.new()

func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < rows and cell.y >= 0 and cell.y < columns

func tile_at(cell: Vector2i) -> BattlefieldTileData:
	return tiles.get(cell)

func is_walkable(cell: Vector2i) -> bool:
	return contains(cell) and tile_at(cell).is_walkable()

func can_enter(cell: Vector2i) -> bool:
	return is_walkable(cell) and not is_structure(cell) and tile_at(cell).terrain != BattlefieldTileData.Terrain.CASTLE

func is_structure(cell: Vector2i) -> bool:
	return contains(cell) and tile_at(cell).building_anchor != NONE

func footprint(anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(buildings.get(anchor, [anchor]))
	return result

func objectives(kind: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for anchor in buildings:
		if tile_at(anchor).terrain == kind: result.append(anchor)
	return result

func capture_ring(anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in footprint(anchor):
		for row in [-1, 0, 1]:
			for col in [-1, 0, 1]:
				var neighbor: Vector2i = cell + Vector2i(row, col)
				if can_enter(neighbor) and tile_at(neighbor).elevation == tile_at(anchor).elevation and neighbor not in result:
					result.append(neighbor)
	return result

func ring_teams(anchor: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for cell in capture_ring(anchor):
		var unit := at(cell)
		if unit != null and unit.team not in result: result.append(unit.team)
	return result

static func inside(cell: Vector2i) -> bool:
	# Compatibility for the classic UI only. Rules use instance-specific contains().
	return cell.x >= 0 and cell.x < 8 and cell.y >= 0 and cell.y < 8

func at(cell: Vector2i) -> UnitState:
	return units.get(cell)

func spawn(data: Resource, team: int, cell: Vector2i) -> UnitState:
	assert(data is UnitData or (data is PieceVariantData and data.kind == "unit"))
	assert(team in [0, 1] and can_enter(cell) and at(cell) == null)
	var unit := UnitState.new(next_uid, data, team, cell)
	next_uid += 1
	units[cell] = unit
	return unit

func move(unit: UnitState, target: Vector2i) -> void:
	assert(can_enter(target) and at(target) == null)
	units.erase(unit.cell)
	unit.cell = target
	unit.has_moved = true
	units[target] = unit

func remove(unit: UnitState) -> void:
	units.erase(unit.cell)

func king(side: int) -> UnitState:
	for unit in units.values():
		if unit.team == side and unit.chess_type == "KING":
			return unit
	return null

func copy(copy_tiles: bool = true) -> BoardState:
	var result := BoardState.new(rows, columns, false)
	if copy_tiles:
		for cell in tiles:
			result.tiles[cell] = tiles[cell].duplicate()
	else:
		# Read-only terrain for move search. Never mutate these tiles in a simulation.
		result.tiles = tiles
	result.next_uid = next_uid
	result.castles = castles.duplicate()
	result.vanguards = vanguards.duplicate(true)
	result.buildings = buildings.duplicate(true)
	result.en_passant_target = en_passant_target
	result.en_passant_pawn = en_passant_pawn
	for cell in units:
		result.units[cell] = units[cell].copy()
	return result
