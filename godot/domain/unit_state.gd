class_name UnitState
extends RefCounted
## Position and movement history only. Variants have no combat stats.
var uid: int
var variant_id: String
var chess_type: String
var team: int
var cell: Vector2i
var has_moved: bool = false
var castle_eligible: bool = false

func _init(number: int, data: PieceVariantData, side: int, square: Vector2i) -> void:
	uid = number
	variant_id = data.id
	chess_type = data.base_chess_type
	team = side
	cell = square

func copy() -> UnitState:
	var data := PieceVariantData.new()
	data.id = variant_id
	data.base_chess_type = chess_type
	var result := UnitState.new(uid, data, team, cell)
	result.has_moved = has_moved
	result.castle_eligible = castle_eligible
	return result
