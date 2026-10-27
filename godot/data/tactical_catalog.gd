class_name TacticalCatalog
extends RefCounted
## Tactical data is authored as resources; legacy king/spell entries remain in Catalog.
const IDS := ["phalanx", "cavalry", "assassin", "ram", "trebuchet", "golem", "queen", "vanguard"]
const DEFAULT_RESERVE := ["phalanx", "cavalry", "assassin", "ram", "queen"]
var entries: Dictionary = {}

func _init() -> void:
	for id in IDS:
		var data := load("res://data/units/%s.tres" % id) as UnitData
		assert(data != null and data.validation_error().is_empty(), "Invalid UnitData: " + id)
		assert(not entries.has(data.id))
		entries[data.id] = data

func get_unit(id: StringName) -> UnitData:
	return entries.get(id)

func valid_reserve(ids: Array) -> bool:
	if ids.size() != 5:
		return false
	for role in range(5):
		if not (ids[role] is String or ids[role] is StringName):
			return false
		var data := get_unit(ids[role])
		if data == null or data.chess_role != role:
			return false
	return true

func variants_for(role: UnitData.ChessRole) -> Array[UnitData]:
	var result: Array[UnitData] = []
	for data in entries.values():
		if data.chess_role == role:
			result.append(data)
	return result
