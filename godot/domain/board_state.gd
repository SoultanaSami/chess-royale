class_name BoardState
extends RefCounted
## Coordinates are (row, column); white starts on rows 6 and 7.
const NONE := Vector2i(-1, -1)
var units: Dictionary = {}
var next_uid: int = 1
var en_passant_target := NONE
var en_passant_pawn := NONE

static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 8 and cell.y >= 0 and cell.y < 8

func at(cell: Vector2i) -> UnitState:
	return units.get(cell)

func spawn(data: PieceVariantData, team: int, cell: Vector2i) -> UnitState:
	assert(data.kind == "unit" and inside(cell) and at(cell) == null)
	var unit := UnitState.new(next_uid, data, team, cell)
	next_uid += 1
	units[cell] = unit
	return unit

func move(unit: UnitState, target: Vector2i) -> void:
	assert(inside(target) and at(target) == null)
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

func copy() -> BoardState:
	var result := BoardState.new()
	result.next_uid = next_uid
	result.en_passant_target = en_passant_target
	result.en_passant_pawn = en_passant_pawn
	for cell in units:
		result.units[cell] = units[cell].copy()
	return result
