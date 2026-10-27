class_name UnitData
extends Resource
## Immutable definition shared by units. Position/history/ability instances live in UnitState.
enum ChessRole { PAWN, KNIGHT, BISHOP, ROOK, QUEEN }

@export var id: StringName
@export var unit_name: String
@export var chess_role: ChessRole = ChessRole.PAWN
@export_range(0, 99) var resource_cost: int = 1
## Figurine only: UnitView supplies the common stone pedestal and team ring.
@export var mesh_prefab: PackedScene
## Trusted project script extending UnitAbility; never load scripts from user deck JSON.
@export var custom_ability_script: Script
## Zero means no ranged attack. Ground movement is unaffected by this capability.
@export_range(1, 4) var max_move_range: int = 2
@export_range(1, 4) var attack_range: int = 1
@export var ranged: bool = false
@export_range(1, 2) var knight_jumps: int = 1
var ranged_attack_range: int:
	get: return attack_range if ranged else 0

func chess_type() -> String:
	return ChessRole.keys()[chess_role]

func validation_error() -> String:
	if id == &"" or unit_name.strip_edges().is_empty():
		return "Unit needs an ID and a name."
	if chess_role < ChessRole.PAWN or chess_role > ChessRole.QUEEN:
		return "Unit needs one of the five chess roles."
	if resource_cost < 0 or max_move_range < 1 or max_move_range > 4 or attack_range < 1 or attack_range > 4 or knight_jumps < 1 or knight_jumps > 2 or mesh_prefab == null:
		return "Invalid cost, range or missing mesh prefab."
	if custom_ability_script != null:
		var base: Script = custom_ability_script
		while base != null and base != preload("res://domain/unit_ability.gd"):
			base = base.get_base_script()
		if base == null or not custom_ability_script.can_instantiate():
			return "Ability script must extend UnitAbility."
	return ""

func create_ability() -> UnitAbility:
	if custom_ability_script == null:
		return null
	assert(validation_error().is_empty())
	return custom_ability_script.new() as UnitAbility
