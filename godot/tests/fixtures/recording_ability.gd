extends UnitAbility
var events: Array[String] = []

func on_deploy(_board: BoardState, _unit: UnitState) -> void:
	events.append("deploy")

func on_move(_board: BoardState, _unit: UnitState, _from: Vector2i) -> void:
	events.append("move")

func on_capture(_board: BoardState, _unit: UnitState, _captured: UnitState) -> void:
	events.append("capture")

func on_turn_end(_board: BoardState, _unit: UnitState) -> void:
	events.append("turn_end")
