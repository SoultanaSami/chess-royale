class_name UnitAbility
extends RefCounted
## One instance per deployed unit. Hooks run only on committed actions, never
## during target previews, board copying or chess king-safety simulation.

func on_deploy(_board: BoardState, _unit: UnitState) -> void:
	pass

func on_move(_board: BoardState, _unit: UnitState, _from: Vector2i) -> void:
	pass

func on_capture(_board: BoardState, _unit: UnitState, _captured: UnitState) -> void:
	pass

func on_turn_end(_board: BoardState, _unit: UnitState) -> void:
	pass
