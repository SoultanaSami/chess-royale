class_name MovementRules
extends RefCounted
## Geometric attacks and legal moves are deliberately separate: pinned pieces
## still attack squares for king movement and castling. Simulation is isolated.
const ORTHOGONAL = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const LEAPS = [Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1), Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)]
const PROMOTIONS = {"queen": "QUEEN", "ram": "ROOK", "assassin": "BISHOP", "cavalry": "KNIGHT"}

static func attacked(board: BoardState, square: Vector2i, by_team: int) -> bool:
	for unit in board.units.values():
		if unit.team != by_team:
			continue
		var delta: Vector2i = square - unit.cell
		match unit.chess_type:
			"PAWN":
				if delta.x == (-1 if by_team == 0 else 1) and absi(delta.y) == 1:
					return true
			"KNIGHT":
				if delta in LEAPS:
					return true
			"KING":
				if maxi(absi(delta.x), absi(delta.y)) == 1:
					return true
			_:
				if delta == Vector2i.ZERO:
					continue
				var straight := delta.x == 0 or delta.y == 0
				var diagonal := absi(delta.x) == absi(delta.y)
				if not ((straight and unit.chess_type in ["ROOK", "QUEEN"]) or (diagonal and unit.chess_type in ["BISHOP", "QUEEN"])):
					continue
				var step := Vector2i(signi(delta.x), signi(delta.y))
				var cell: Vector2i = unit.cell + step
				while cell != square and board.at(cell) == null:
					cell += step
				if cell == square:
					return true
	return false

static func in_check(board: BoardState, side: int) -> bool:
	var king := board.king(side)
	# Invalid kingless positions must never yield legal commands.
	return king == null or attacked(board, king.cell, 1 - side)

static func pseudo_targets(board: BoardState, unit: UnitState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit.chess_type == "PAWN":
		var direction := -1 if unit.team == 0 else 1
		var forward := unit.cell + Vector2i(direction, 0)
		if board.inside(forward) and board.at(forward) == null:
			result.append(forward)
			var start_row := 6 if unit.team == 0 else 1
			var twice := forward + Vector2i(direction, 0)
			if not unit.has_moved and unit.cell.x == start_row and board.at(twice) == null:
				result.append(twice)
		for side in [-1, 1]:
			var diagonal := unit.cell + Vector2i(direction, side)
			if not board.inside(diagonal):
				continue
			var occupant := board.at(diagonal)
			if occupant != null and occupant.team != unit.team and occupant.chess_type != "KING":
				result.append(diagonal)
			elif occupant == null and diagonal == board.en_passant_target:
				var pawn := board.at(board.en_passant_pawn)
				if pawn != null and pawn.chess_type == "PAWN" and pawn.team != unit.team and pawn.cell == Vector2i(unit.cell.x, diagonal.y):
					result.append(diagonal)
		return result
	if unit.chess_type in ["KNIGHT", "KING"]:
		var steps: Array = LEAPS if unit.chess_type == "KNIGHT" else ORTHOGONAL + DIAGONAL
		for step in steps:
			var target: Vector2i = unit.cell + step
			if can_land(board, unit, target):
				result.append(target)
		return result
	var directions: Array = ORTHOGONAL if unit.chess_type == "ROOK" else DIAGONAL
	if unit.chess_type == "QUEEN":
		directions = ORTHOGONAL + DIAGONAL
	for direction in directions:
		for distance in range(1, 8):
			var target: Vector2i = unit.cell + direction * distance
			if not board.inside(target):
				break
			if can_land(board, unit, target):
				result.append(target)
			if board.at(target) != null:
				break
	return result

static func can_land(board: BoardState, unit: UnitState, target: Vector2i) -> bool:
	if not board.inside(target):
		return false
	var occupant := board.at(target)
	return occupant == null or (occupant.team != unit.team and occupant.chess_type != "KING")

static func castle_targets(board: BoardState, king: UnitState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var row := 7 if king.team == 0 else 0
	if king.chess_type != "KING" or king.has_moved or not king.castle_eligible or king.cell != Vector2i(row, 4) or in_check(board, king.team):
		return result
	for col in [0, 7]:
		var rook := board.at(Vector2i(row, col))
		if rook == null or rook.team != king.team or rook.chess_type != "ROOK" or rook.has_moved or not rook.castle_eligible:
			continue
		var direction := -1 if col == 0 else 1
		var clear := true
		for path_col in range(4 + direction, col, direction):
			if board.at(Vector2i(row, path_col)) != null:
				clear = false
		if not clear:
			continue
		# Remove the king from E before checking the transit square.
		var transit := board.copy()
		transit.move(transit.at(king.cell), Vector2i(row, 4 + direction))
		if not in_check(transit, king.team):
			result.append(Vector2i(row, 4 + 2 * direction))
	return result

static func targets(board: BoardState, unit: UnitState) -> Array[Vector2i]:
	var legal: Array[Vector2i] = []
	var candidates := pseudo_targets(board, unit)
	if unit.chess_type == "KING":
		candidates.append_array(castle_targets(board, unit))
	for target in candidates:
		var next := board.copy()
		apply_move(next, next.at(unit.cell), target)
		if not in_check(next, unit.team):
			legal.append(target)
	return legal

static func has_legal_move(board: BoardState, side: int) -> bool:
	for unit in board.units.values():
		if unit.team == side and not targets(board, unit).is_empty():
			return true
	return false

static func needs_promotion(unit: UnitState, to: Vector2i) -> bool:
	return unit.chess_type == "PAWN" and to.x == (0 if unit.team == 0 else 7)

static func apply_move(board: BoardState, unit: UnitState, to: Vector2i, promotion: String = "queen") -> Dictionary:
	# Internal primitive: callers must validate legality first, including castling.
	var from := unit.cell
	var kind := unit.chess_type
	var captured := board.at(to)
	if kind == "PAWN" and to == board.en_passant_target and captured == null and from.y != to.y:
		captured = board.at(board.en_passant_pawn)
	if captured != null:
		assert(captured.team != unit.team and captured.chess_type != "KING")
		CombatSystem.capture(board, unit, captured)
	board.en_passant_target = BoardState.NONE
	board.en_passant_pawn = BoardState.NONE
	board.move(unit, to)
	var castling := kind == "KING" and absi(to.y - from.y) == 2
	if castling:
		var rook := board.at(Vector2i(from.x, 7 if to.y == 6 else 0))
		board.move(rook, Vector2i(from.x, 5 if to.y == 6 else 3))
	if kind == "PAWN" and absi(to.x - from.x) == 2:
		board.en_passant_target = Vector2i((from.x + to.x) / 2, from.y)
		board.en_passant_pawn = to
	if needs_promotion(unit, to):
		unit.variant_id = promotion
		unit.chess_type = PROMOTIONS[promotion]
		unit.castle_eligible = false
	return {"captured": captured, "castling": castling}
