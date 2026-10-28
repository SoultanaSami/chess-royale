class_name TacticalField
extends RefCounted
## Stage-one movement sandbox. No CP, currency or victory rules are implied here.
## The future command manager should validate its action budget before committing.
signal changed
var board: BoardState
var catalog := TacticalCatalog.new()

func _init(config: BattlefieldConfig) -> void:
	board = config.create_board()

func deploy_unit(data: UnitData, side: int, cell: Vector2i) -> UnitState:
	if data == null or not data.validation_error().is_empty() or side not in [0, 1]:
		return null
	if not board.can_enter(cell) or board.at(cell) != null:
		return null
	var unit := board.spawn(data, side, cell)
	unit.ability = data.create_ability()
	if unit.ability != null:
		unit.ability.on_deploy(board, unit)
	changed.emit()
	return unit

func seed_vanguard(decks: Array = []) -> bool:
	var placements: Array[Dictionary] = []
	var middle := board.columns / 2
	for side in [0, 1]:
		var keep := TacticalCommands.castle(board, side)
		var forward := Vector2i(-1 if side == 0 else 1, 0)
		var spawn_cells: Array = board.vanguards.get(side, [])
		if spawn_cells.is_empty():
			var front := -1 if side == 0 else 2
			spawn_cells = [keep + Vector2i(front,0), keep + Vector2i(front,1), keep + Vector2i(0,-1), keep + Vector2i(0,2)]
		if spawn_cells.size() != 4: return false
		var ids := ["phalanx", "phalanx", "cavalry", "ram"]
		for i in range(4):
			placements.append({"id": ids[i], "side": side, "cell": spawn_cells[i]})
	for placement in placements:
		if not board.can_enter(placement.cell) or board.at(placement.cell) != null:
			return false
	for placement in placements:
		var id: String = placement.id
		if not decks.is_empty():
			id = decks[placement.side][catalog.get_unit(id).chess_role]
		deploy_unit(catalog.get_unit(id), placement.side, placement.cell)
	return true

func legal_targets(cell: Vector2i) -> Array[Vector2i]:
	var unit := board.at(cell)
	if unit == null:
		return []
	return MovementRules.pseudo_targets(board, unit)

func move_unit(from: Vector2i, to: Vector2i) -> bool:
	var unit := board.at(from)
	if unit == null or to not in legal_targets(from):
		return false
	var captured := board.at(to)
	if captured != null:
		board.remove(captured)
	board.move(unit, to)
	unit.position_history.append(to)
	if unit.ability != null:
		if captured != null:
			unit.ability.on_capture(board, unit, captured)
		unit.ability.on_move(board, unit, from)
	changed.emit()
	return true

func notify_turn_end(side: int) -> void:
	# Explicit hook for the future CP controller. Never invoked by movement previews.
	for unit in board.units.values():
		if unit.team == side and board.at(unit.cell) == unit and unit.ability != null:
			unit.ability.on_turn_end(board, unit)
