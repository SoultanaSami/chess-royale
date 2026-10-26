class_name GameManager
extends RefCounted
## Authoritative match: exactly one legal move, then immediate side change.
signal changed
signal event_occurred(event: Dictionary)
var catalog: Catalog
var board: BoardState
var turn: int = 0
var round_number: int = 1
var ply_count: int = 0
var starting_decks: Array = [[], []]
var winner: int = -1
var finished: bool = false
var result_reason: String = ""
var history: Array[String] = []
var last_error: String = ""

func _init(data: Catalog, deck: Array = Catalog.DEFAULT_DECK) -> void:
	catalog = data
	assert(catalog.valid_deck(deck))
	board = BoardState.new()
	for side in [0, 1]:
		var cards: Array = deck.duplicate() if side == 0 else Catalog.DEFAULT_DECK.duplicate()
		starting_decks[side] = cards.duplicate()
		for placement in StartingArmy.formation(catalog, cards, side):
			var unit := board.spawn(catalog.get_piece(placement.id), side, placement.cell)
			unit.castle_eligible = unit.chess_type in ["KING", "ROOK"]

func reject(reason: String) -> bool:
	last_error = reason
	return false

func can_act() -> bool:
	return not finished

func legal_targets(from: Vector2i) -> Array[Vector2i]:
	var unit := board.at(from)
	if finished or unit == null or unit.team != turn:
		return []
	return MovementRules.targets(board, unit)

func move_unit(from: Vector2i, to: Vector2i, promotion: String = "") -> bool:
	if finished:
		return reject("Die Partie ist beendet.")
	var unit := board.at(from)
	if unit == null or unit.team != turn:
		return reject("Wähle eine Figur der Seite am Zug.")
	if to not in legal_targets(from):
		return reject("Ungültiger Zug. Der eigene König muss sicher bleiben.")
	if MovementRules.needs_promotion(unit, to):
		if not MovementRules.PROMOTIONS.has(promotion):
			return reject("Für die Umwandlung Dame, Turm, Läufer oder Springer wählen.")
	elif not promotion.is_empty():
		return reject("Eine Umwandlung ist nur auf der letzten Reihe möglich.")
	var result := MovementRules.apply_move(board, unit, to, promotion if not promotion.is_empty() else "queen")
	var move_text := "%s %s %s" % [notation(from), "×" if result.captured != null else "→", notation(to)]
	if result.castling:
		move_text = "O–O" if to.y == 6 else "O–O–O"
	if not promotion.is_empty():
		move_text += " · Umwandlung"
	history.append(move_text)
	if history.size() > 40:
		history.pop_front()
	ply_count += 1
	turn = 1 - turn
	if turn == 0:
		round_number += 1
	last_error = ""
	update_outcome()
	event_occurred.emit({"kind": "capture" if result.captured != null else "move", "from": from, "to": to, "uid": unit.uid})
	changed.emit()
	return true

func in_check(side: int) -> bool:
	return MovementRules.in_check(board, side)

func update_outcome() -> void:
	if finished:
		return
	if not MovementRules.has_legal_move(board, turn):
		finished = true
		if in_check(turn):
			winner = 1 - turn
			result_reason = "Schachmatt"
		else:
			result_reason = "Patt"

func resign(side: int) -> bool:
	if finished or side not in [0, 1]:
		return false
	finished = true
	winner = 1 - side
	result_reason = "Aufgabe"
	changed.emit()
	return true

static func notation(cell: Vector2i) -> String:
	return "%s%d" % [char(65 + cell.y), 8 - cell.x]
