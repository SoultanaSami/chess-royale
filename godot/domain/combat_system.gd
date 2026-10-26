class_name CombatSystem
extends RefCounted
## A capture removes one enemy immediately. The king is never captured.
static func capture(board: BoardState, attacker: UnitState, defender: UnitState) -> bool:
	if defender == null or defender.team == attacker.team or defender.chess_type == "KING":
		return false
	board.remove(defender)
	return true
