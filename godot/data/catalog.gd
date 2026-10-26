class_name Catalog
extends RefCounted

var entries: Dictionary = {}
var ordered_ids: Array[String] = []
const SLOT_TYPES: Array[String] = ["ROOK","KNIGHT","BISHOP","QUEEN","KING","BISHOP","KNIGHT","ROOK","PAWN","PAWN","PAWN","PAWN","PAWN","PAWN","PAWN","PAWN"]
const DEFAULT_DECK: Array[String] = ["ram","cavalry","assassin","queen","guard","assassin","cavalry","golem","phalanx","phalanx","phalanx","phalanx","phalanx","phalanx","phalanx","phalanx"]

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/variants.json"))
	assert(parsed is Array, "Catalog must be a JSON array")
	for raw in parsed:
		assert(raw is Dictionary and not entries.has(raw.id), "Duplicate or invalid catalog ID")
		assert(raw.baseChessType in ["PAWN", "KNIGHT", "BISHOP", "ROOK", "QUEEN", "KING", "SPELL"])
		entries[raw.id] = PieceVariantData.from_dictionary(raw)
		ordered_ids.append(raw.id)

func get_piece(id: String) -> PieceVariantData:
	return entries.get(id)

func valid_deck(deck: Array) -> bool:
	if deck.size() != 16:
		return false
	for index in range(16):
		var id = deck[index]
		if not id is String or not entries.has(id):
			return false
		var data := get_piece(id)
		if data.kind != "unit" or data.base_chess_type != SLOT_TYPES[index]:
			return false
	return true

func variants_for(kind: String) -> Array[String]:
	var result: Array[String] = []
	for id in ordered_ids:
		if get_piece(id).base_chess_type == kind:
			result.append(id)
	return result
