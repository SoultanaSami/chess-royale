class_name TacticalAI
extends RefCounted
## Position scoring only; material values are not attack or health stats.
const VALUE = {"PAWN": 1.0, "KNIGHT": 3.0, "BISHOP": 3.1, "ROOK": 5.0, "QUEEN": 9.0, "KING": 0.0}
static func act(game: GameManager) -> bool:
	if game.finished:
		return false
	var best: Dictionary = {}
	var best_score: float = -INF
	for unit in game.board.units.values():
		if unit.team != game.turn:
			continue
		for target in game.legal_targets(unit.cell):
			var next := game.board.copy()
			var result := MovementRules.apply_move(next, next.at(unit.cell), target)
			var score: float = (3.5 - absf(target.y - 3.5)) * 0.12
			if result.captured != null:
				score += VALUE[result.captured.chess_type] * 2.0
			if MovementRules.attacked(next, target, 1 - unit.team):
				score -= VALUE[next.at(target).chess_type] * 1.3
			if unit.chess_type == "PAWN":
				score += 0.4
				if MovementRules.needs_promotion(unit, target):
					score += 8.0
			if result.castling:
				score += 0.7
			if MovementRules.in_check(next, 1 - unit.team):
				score += 0.5
				if not MovementRules.has_legal_move(next, 1 - unit.team):
					score += 1000.0
			if score > best_score:
				best_score = score
				best = {"from": unit.cell, "to": target, "promotion": "queen" if MovementRules.needs_promotion(unit, target) else ""}
	if best.is_empty():
		game.update_outcome()
		game.changed.emit()
		return false
	return game.move_unit(best.from, best.to, best.promotion)
