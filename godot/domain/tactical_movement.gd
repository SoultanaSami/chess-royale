class_name TacticalMovement
extends RefCounted
## Capped chess vectors. All preview, AI and siege geometry uses these functions.
static func terrain_cost(board: BoardState, cell: Vector2i) -> int:
	return 2 if board.tile_at(cell).forest else 1

static func can_step(board: BoardState, from: Vector2i, to: Vector2i, role: String, attack: bool = false) -> bool:
	if not board.contains(from) or not board.is_walkable(to): return false
	if not attack and not board.can_enter(to): return false
	if role == "ROOK" and board.tile_at(to).forest: return false
	var a := board.tile_at(from)
	var b := board.tile_at(to)
	if a.elevation == b.elevation: return true
	if absi(a.elevation - b.elevation) != 1: return false
	var lower := a if a.elevation < b.elevation else b
	var uphill := to - from if a.elevation < b.elevation else from - to
	return lower.ramp and Vector2(uphill).dot(Vector2(lower.ramp_direction)) > 0

static func targets(board: BoardState, unit: UnitState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.chess_type == "KNIGHT": return knight_targets(board, unit, false)
	if unit.chess_type == "PAWN":
		var step := Vector2i(-1 if unit.team == 0 else 1, 0)
		var from := unit.cell
		var budget := mini(2, unit.definition.max_move_range)
		for distance in range(1, 3):
			var to := unit.cell + step * distance
			if not can_step(board, from, to, "PAWN") or board.at(to) != null: break
			budget -= terrain_cost(board, to)
			if budget < 0: break
			result.append(to)
			from = to
		for offset in [Vector2i(step.x,-1), Vector2i(step.x,1)]:
			var to: Vector2i = unit.cell + offset
			if can_step(board, unit.cell, to, "PAWN") and terrain_cost(board, to) <= unit.definition.max_move_range and board.at(to) != null and board.at(to).team != unit.team:
				result.append(to)
		return result
	return sliding(board, unit, false)

static func attack_targets(board: BoardState, unit: UnitState) -> Array[Vector2i]:
	if unit.chess_type == "KNIGHT": return knight_targets(board, unit, true)
	var result: Array[Vector2i] = []
	if unit.chess_type == "PAWN":
		for col in [-1, 1]:
			var to := unit.cell + Vector2i(-1 if unit.team == 0 else 1, col)
			if can_step(board, unit.cell, to, "PAWN", true): result.append(to)
		return result
	return sliding(board, unit, true)

static func sliding(board: BoardState, unit: UnitState, attack: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var directions: Array = MovementRules.ORTHOGONAL if unit.chess_type == "ROOK" else MovementRules.DIAGONAL
	if unit.chess_type == "QUEEN": directions = MovementRules.ORTHOGONAL + MovementRules.DIAGONAL
	var cap := 3 if unit.chess_type == "BISHOP" else 4
	for step in directions:
		var budget := mini(cap, unit.definition.attack_range if attack else unit.definition.max_move_range)
		var from := unit.cell
		for distance in range(1, cap + 1):
			var to: Vector2i = unit.cell + step * distance
			if not can_step(board, from, to, unit.chess_type, attack): break
			budget -= terrain_cost(board, to)
			if budget < 0: break
			var occupant := board.at(to)
			if attack or occupant == null or (occupant.team != unit.team and distance <= unit.definition.attack_range): result.append(to)
			if occupant != null or board.tile_at(to).terrain == BattlefieldTileData.Terrain.CASTLE: break
			from = to
	return result

static func knight_targets(board: BoardState, unit: UnitState, attack: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [unit.cell]
	for jump in range(unit.definition.knight_jumps):
		var next: Array[Vector2i] = []
		for from in frontier:
			for leap in MovementRules.LEAPS:
				var to: Vector2i = from + leap
				var delta := to - unit.cell
				if to == unit.cell or maxi(absi(delta.x), absi(delta.y)) > (unit.definition.attack_range if attack else unit.definition.max_move_range): continue
				if not board.is_walkable(to) or (not attack and not board.can_enter(to)): continue
				var occupant := board.at(to)
				if (attack or occupant == null or occupant.team != unit.team) and to not in result: result.append(to)
				if occupant == null and board.can_enter(to) and to not in next: next.append(to)
		frontier = next
	return result

static func has_vision(board: BoardState, team: int, target: Vector2i) -> bool:
	# Spotting high ground requires an allied scout at equal/higher elevation,
	# within four tiles with an unobstructed view. The garrison is also a lookout.
	var sources: Array[Vector2i] = [TacticalCommands.castle(board, team)]
	for unit in board.units.values():
		if unit.team == team: sources.append(unit.cell)
	for from in sources:
		var delta := target - from
		if board.tile_at(from).elevation >= board.tile_at(target).elevation and maxi(absi(delta.x), absi(delta.y)) <= 4 and line_visible(board, from, target): return true
	return false

static func line_visible(board: BoardState, from: Vector2i, to: Vector2i) -> bool:
	var count := maxi(absi(to.x-from.x), absi(to.y-from.y))
	var ceiling := maxi(board.tile_at(from).elevation, board.tile_at(to).elevation)
	for i in range(1, count):
		var cell := Vector2i(Vector2(from).lerp(Vector2(to), float(i)/count).round())
		if board.tile_at(cell).elevation > ceiling: return false
	return true

static func ranged_targets(board: BoardState, unit: UnitState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not unit.definition.ranged: return result
	var directions: Array = MovementRules.DIAGONAL if unit.chess_type == "BISHOP" else MovementRules.ORTHOGONAL
	if unit.chess_type == "QUEEN": directions = MovementRules.ORTHOGONAL + MovementRules.DIAGONAL
	var reach := unit.definition.attack_range
	var level := board.tile_at(unit.cell).elevation
	if unit.chess_type == "BISHOP" and level == 2: reach += 1
	for step in directions:
		for distance in range(1, reach + 1):
			var to: Vector2i = unit.cell + step * distance
			if not board.contains(to): break
			var spotted := board.tile_at(to).elevation <= level or has_vision(board, unit.team, to)
			if spotted and board.is_walkable(to) and line_visible(board, unit.cell, to): result.append(to)
			if board.at(to) != null or board.tile_at(to).terrain == BattlefieldTileData.Terrain.CASTLE: break
	return result
