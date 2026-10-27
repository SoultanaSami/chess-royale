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
var definition: UnitData
var ability: UnitAbility
var position_history: Array[Vector2i] = []

func _init(number: int, data: Resource, side: int, square: Vector2i) -> void:
	uid = number
	variant_id = data.id
	if data is UnitData:
		definition = data
		chess_type = data.chess_type()
	else:
		chess_type = data.base_chess_type
	team = side
	cell = square
	position_history.append(square)

func copy() -> UnitState:
	var data := PieceVariantData.new()
	data.id = variant_id
	data.base_chess_type = chess_type
	var result := UnitState.new(uid, data, team, cell)
	result.has_moved = has_moved
	result.castle_eligible = castle_eligible
	result.definition = definition
	result.position_history = position_history.duplicate()
	# Simulation copies do not share or instantiate live ability state.
	return result
