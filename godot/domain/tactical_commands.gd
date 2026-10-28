class_name TacticalCommands
extends RefCounted
## Shared command geometry for UI, AI and exact multi-command siege search.
static func castle(board: BoardState, side: int) -> Vector2i:
	return board.castles.get(side, Vector2i(board.rows - 1 if side == 0 else 0, board.columns / 2))

static func threats(board: BoardState, side: int) -> Array[UnitState]:
	var result: Array[UnitState] = []
	var targets := board.footprint(castle(board, side))
	for unit in board.units.values():
		if unit.team == side: continue
		for target in targets:
			if MovementRules.attacks_from(board, unit, target) or target in MovementRules.ranged_targets(board, unit):
				result.append(unit)
				break
	return result

static func deployment_cells(board: BoardState, side: int, role: String = "") -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in board.capture_ring(castle(board, side)):
		if board.at(cell) == null and not (role == "ROOK" and board.tile_at(cell).forest):
			result.append(cell)
	return result

static func formation_valid(board: BoardState, cells: Array, side: int) -> bool:
	# A phalanx is a contiguous horizontal row, all advancing one square together.
	if cells.size() < 2:
		return false
	var seen := {}
	var min_col := board.columns
	var max_col := -1
	var row := -1
	for cell in cells:
		if not cell is Vector2i or seen.has(cell):
			return false
		seen[cell] = true
		var unit := board.at(cell)
		if unit == null or unit.team != side or unit.chess_type != "PAWN":
			return false
		if row != -1 and cell.x != row:
			return false
		row = cell.x
		min_col = mini(min_col, cell.y)
		max_col = maxi(max_col, cell.y)
		var to: Vector2i = cell + Vector2i(-1 if side == 0 else 1, 0)
		if not board.can_enter(to) or board.at(to) != null or to not in MovementRules.pseudo_targets(board, unit):
			return false
	return max_col - min_col + 1 == cells.size()

static func legal(board: BoardState, action: Dictionary, side: int, deck: Array, gold: int, catalog: TacticalCatalog) -> bool:
	var kind: String = action.get("kind", "")
	if kind == "formation":
		return action.get("cells") is Array and formation_valid(board, action.cells, side)
	if not action.get("to") is Vector2i:
		return false
	if kind == "deploy":
		var slot = action.get("slot")
		if not slot is int or slot < 0 or slot >= deck.size():
			return false
		var data := catalog.get_unit(deck[slot])
		return data != null and data.resource_cost <= gold and action.to in deployment_cells(board, side, data.chess_type())
	if not action.get("from") is Vector2i:
		return false
	var unit := board.at(action.from)
	if unit == null or unit.team != side:
		return false
	if kind == "move":
		return action.to in MovementRules.pseudo_targets(board, unit)
	if kind == "shoot":
		var target := board.at(action.to)
		return target != null and target.team != side and action.to in MovementRules.ranged_targets(board, unit)
	return false

static func actions(board: BoardState, side: int, deck: Array, gold: int, catalog: TacticalCatalog) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in board.units.values():
		if unit.team != side:
			continue
		for to in MovementRules.pseudo_targets(board, unit):
			result.append({"kind": "move", "from": unit.cell, "to": to})
		for to in MovementRules.ranged_targets(board, unit):
			if board.at(to) != null and board.at(to).team != side:
				result.append({"kind": "shoot", "from": unit.cell, "to": to})
		if unit.chess_type == "PAWN":
			var cells: Array = [unit.cell]
			for col in range(unit.cell.y + 1, board.columns):
				cells.append(Vector2i(unit.cell.x, col))
				if not formation_valid(board, cells, side):
					break
				result.append({"kind": "formation", "cells": cells.duplicate()})
	for slot in range(deck.size()):
		if catalog.get_unit(deck[slot]).resource_cost <= gold:
			for cell in deployment_cells(board, side, catalog.get_unit(deck[slot]).chess_type()):
				result.append({"kind": "deploy", "slot": slot, "to": cell})
	return result

static func apply(board: BoardState, action: Dictionary, side: int, deck: Array, catalog: TacticalCatalog, live: bool = false) -> int:
	# Internal commit primitive: caller validates and spends CP before invoking hooks.
	if action.kind == "deploy":
		var data := catalog.get_unit(deck[action.slot])
		var deployed := board.spawn(data, side, action.to)
		if live:
			deployed.ability = data.create_ability()
			if deployed.ability != null:
				deployed.ability.on_deploy(board, deployed)
		return data.resource_cost
	var moves: Array = action.cells if action.kind == "formation" else [action.from]
	for from in moves:
		var unit := board.at(from)
		var to: Vector2i = from + Vector2i(-1 if side == 0 else 1, 0) if action.kind == "formation" else action.to
		var captured := board.at(to)
		if captured != null:
			board.remove(captured)
		if action.kind != "shoot":
			board.move(unit, to)
			unit.position_history.append(to)
		if live and unit.ability != null:
			if captured != null:
				unit.ability.on_capture(board, unit, captured)
			if action.kind != "shoot":
				unit.ability.on_move(board, unit, from)
		if action.kind != "shoot" and unit.chess_type == "PAWN" and to.x == (0 if side == 0 else board.rows - 1):
			unit.definition = catalog.get_unit(deck[4])
			unit.variant_id = unit.definition.id
			unit.chess_type = "QUEEN"
			if live:
				unit.ability = unit.definition.create_ability()
	return 0
