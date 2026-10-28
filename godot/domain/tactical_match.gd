class_name TacticalMatch
extends RefCounted
signal changed
signal event_occurred(event: Dictionary)
enum Phase { ACTION, RESOLVING, FINISHED }
var phase := Phase.ACTION
var field: TacticalField
var config: BattlefieldConfig
var board: BoardState:
	get: return field.board
var catalog: TacticalCatalog:
	get: return field.catalog
var reserves: Array = []
var gold: Array[int] = [10, 10]
var cp: int = 3
var remaining_time: float = 0
var turn: int = 0
var round_number: int = 1
var winner: int = -1
var result_reason: String = ""
var last_error: String = ""
var last_event: String = "Die Schlacht beginnt."
var siege: Array[bool] = [false, false]
var searches: Array = [null, null]
var finished: bool:
	get: return phase == Phase.FINISHED

func _init(layout: BattlefieldConfig, deck: Array = TacticalCatalog.DEFAULT_RESERVE) -> void:
	config = layout
	field = TacticalField.new(config)
	assert(catalog.valid_reserve(deck))
	reserves = [deck.duplicate(), TacticalCatalog.DEFAULT_RESERVE.duplicate()]
	assert(field.seed_vanguard(reserves))
	gold = [config.starting_gold, config.starting_gold]
	cp = config.max_cp
	remaining_time = config.turn_time_limit
	# Start gold is the first-turn budget; subsequent turns grant income.
	refresh_siege()

func reject(reason: String) -> bool:
	last_error = reason
	return false

func can_act(side: int) -> bool:
	return phase == Phase.ACTION and side == turn and cp > 0

func legal_targets(cell: Vector2i) -> Array[Vector2i]:
	var unit := board.at(cell)
	if unit == null or not can_act(unit.team):
		return []
	return MovementRules.pseudo_targets(board, unit)

func deploy_targets(slot: int, side: int) -> Array[Vector2i]:
	if not can_act(side) or slot < 0 or slot >= 5 or catalog.get_unit(reserves[side][slot]).resource_cost > gold[side]:
		return []
	return TacticalCommands.deployment_cells(board, side, catalog.get_unit(reserves[side][slot]).chess_type())

func execute(action: Dictionary, side: int) -> bool:
	if not can_act(side):
		return reject("Du bist nicht am Zug oder hast keine KP mehr.")
	if not TacticalCommands.legal(board, action, side, reserves[side], gold[side], catalog):
		return reject("Befehl nicht möglich: Ziel, Formation oder Gold prüfen.")
	phase = Phase.RESOLVING
	cp -= 1
	var cost := catalog.get_unit(reserves[side][action.slot]).resource_cost if action.kind == "deploy" else 0
	gold[side] -= cost
	TacticalCommands.apply(board, action, side, reserves[side], catalog, true)
	last_error = ""
	last_event = {"move": "Figur bewegt", "deploy": "Verstärkung eingetroffen", "shoot": "Fernangriff", "formation": "Phalanx vorgerückt"}[action.kind]
	phase = Phase.ACTION
	refresh_siege()
	event_occurred.emit(action)
	changed.emit()
	return true

func income(side: int) -> int:
	var amount := config.base_income
	for anchor in board.objectives(BattlefieldTileData.Terrain.RESOURCE_NODE):
		var tile := board.tile_at(anchor)
		if tile.owner == side:
			amount += tile.resource_yield
	return amount

func mines_owned(side: int) -> int:
	var count := 0
	for anchor in board.objectives(BattlefieldTileData.Terrain.RESOURCE_NODE):
		var tile := board.tile_at(anchor)
		if tile.owner == side:
			count += 1
	return count

func end_turn(side: int) -> bool:
	if phase != Phase.ACTION or turn != side:
		return reject("Zug kann gerade nicht beendet werden.")
	phase = Phase.RESOLVING
	field.notify_turn_end(side)
	for anchor in board.objectives(BattlefieldTileData.Terrain.RESOURCE_NODE):
		var occupants := board.ring_teams(anchor)
		if occupants.size() == 1 and occupants[0] == side:
			board.tile_at(anchor).owner = side
	var castle_tile := board.tile_at(TacticalCommands.castle(board, side))
	if not TacticalCommands.threats(board, side).is_empty():
		castle_tile.garrison_shields -= 1
		last_event = "Belagerung! Ein Garnisonsschild verloren."
		if castle_tile.garrison_shields <= 0:
			finish(1 - side, "Burg gefallen")
			return true
	else:
		last_event = "Zug beendet."
	turn = 1 - side
	if turn == 0:
		round_number += 1
	gold[turn] += income(turn)
	cp = config.max_cp
	remaining_time = config.turn_time_limit
	phase = Phase.ACTION
	refresh_siege()
	changed.emit()
	return true

func tick(delta: float) -> void:
	if phase != Phase.ACTION or config.turn_time_limit <= 0:
		return
	remaining_time = maxf(0, remaining_time - maxf(0, delta))
	if remaining_time <= 0:
		end_turn(turn)

func refresh_siege() -> void:
	searches = [null, null]
	for side in [0, 1]:
		siege[side] = not TacticalCommands.threats(board, side).is_empty()
		if siege[side] and not finished:
			# A full response window: exhausted CP alone must never count as mate.
			var budget := gold[side] + (income(side) if side != turn or cp < config.max_cp else 0)
			searches[side] = SiegeSearch.new(board, side, reserves[side], budget, config.max_cp, catalog)

func advance_siege_search() -> void:
	if finished:
		return
	for side in [turn, 1 - turn]:
		var search: SiegeSearch = searches[side]
		if search != null:
			search.advance(2000)
			if search.done and not search.defensible:
				finish(1 - side, "Schachmatt — keine Verteidigung möglich")
				return

func resign(side: int) -> void:
	if not finished and side in [0, 1]:
		finish(1 - side, "Aufgabe")

func finish(side: int, reason: String) -> void:
	winner = side
	result_reason = reason
	phase = Phase.FINISHED
	searches = [null, null]
	changed.emit()
