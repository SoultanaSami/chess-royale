class_name PieceVariantData
extends Resource
## Appearance and declared rules; no HP, damage, costs or progression.
@export var id: String
@export var display_name: String
@export var base_chess_type: String
@export var model_asset_path: String
@export var description: String
@export var kind: String = "unit"
@export var rules_status: String = "classical"
@export var open_rules: String = ""

static func from_dictionary(raw: Dictionary) -> PieceVariantData:
	var data := PieceVariantData.new()
	data.id = raw.id
	data.display_name = raw.name
	data.base_chess_type = raw.baseChessType
	data.model_asset_path = raw.modelAssetPath
	data.description = raw.description
	data.kind = raw.get("kind", "unit")
	data.rules_status = raw.rulesStatus
	data.open_rules = raw.openRules
	return data
