class_name SiegeSearch
extends RefCounted
## Exhaustive search over a complete defensive CP window. Time-sliced, never
## converts an unfinished search to mate; includes deployment, fire and phalanxes.
var done := false
var defensible := false
var solution: Array = []
var side: int
var deck: Array
var catalog: TacticalCatalog
var stack: Array[Dictionary] = []
var seen: Dictionary = {}

func _init(board: BoardState, team: int, reserve: Array, gold: int, cp: int, data: TacticalCatalog) -> void:
	side = team
	deck = reserve
	catalog = data
	stack.append({"board": board.copy(false), "gold": gold, "cp": cp, "path": []})
	# Unknown future ability scripts require a simulation contract before mate can
	# be proved. The shipping catalog has no such scripts; shield loss still works.
	for unit in board.units.values():
		if unit.definition != null and unit.definition.custom_ability_script != null:
			done = true
			defensible = true
	for id in deck:
		if catalog.get_unit(id).custom_ability_script != null:
			done = true
			defensible = true

var expanding: Dictionary = {}
var candidates: Array[Dictionary] = []
var action_index: int = 0

func advance(microseconds: int = 3000) -> void:
	var until := Time.get_ticks_usec() + microseconds
	while not done and Time.get_ticks_usec() < until:
		if expanding.is_empty():
			if stack.is_empty():
				done = true
				return
			var state: Dictionary = stack.pop_back()
			var board: BoardState = state.board
			if TacticalCommands.threats(board, side).is_empty():
				done = true
				defensible = true
				solution = state.path
				return
			if state.cp == 0:
				continue
			var key := signature(board, state.gold)
			if seen.get(key, -1) >= state.cp:
				continue
			seen[key] = state.cp
			expanding = state
			candidates = TacticalCommands.actions(board, side, deck, state.gold, catalog)
			action_index = 0
		if action_index >= candidates.size():
			expanding = {}
			continue
		var action: Dictionary = candidates[action_index]
		action_index += 1
		var next: BoardState = expanding.board.copy(false)
		var cost := TacticalCommands.apply(next, action, side, deck, catalog)
		var path: Array = expanding.path.duplicate()
		path.append(action)
		if TacticalCommands.threats(next, side).is_empty():
			done = true
			defensible = true
			solution = path
			return
		if expanding.cp > 1:
			stack.append({"board": next, "gold": expanding.gold - cost, "cp": expanding.cp - 1, "path": path})

func signature(board: BoardState, gold: int) -> String:
	var parts: Array[String] = []
	for unit in board.units.values():
		parts.append("%s:%d:%d:%d:%s" % [unit.cell, unit.team, int(unit.has_moved), unit.uid, unit.variant_id])
	parts.sort()
	return str(gold) + "|" + "|".join(parts)
