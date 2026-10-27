extends SceneTree
var checks := 0
var failures := 0
var catalog := TacticalCatalog.new()

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var config := load("res://data/battlefields/river_crossing.tres") as BattlefieldConfig
	check(config.validation_error().is_empty(), "Authored map is valid")
	var field := TacticalField.new(config)
	var empty_targets: Array[Vector2i] = field.legal_targets(BoardState.NONE)
	check(empty_targets.is_empty(), "Empty selection returns a typed, empty target list")
	check(field.board.rows == 12 and field.board.columns == 16 and field.board.tiles.size() == 192, "Rectangular map has all tiles")
	check(field.seed_vanguard() and field.board.units.size() == 8, "Four starting units per side")
	check(field.board.tile_at(config.castle_cell(0)).owner == 0 and field.board.tile_at(config.castle_cell(1)).owner == 1, "Opposite castle owners")
	check(field.board.tile_at(config.castle_cell(0)).garrison_shields == 3, "Castles hold separate garrison state")
	for cell in config.resource_cells:
		check(field.board.tile_at(cell).owner == -1, "Resource node starts neutral")
	var clone := field.board.copy()
	clone.tile_at(config.resource_cells[0]).owner = 1
	clone.tile_at(config.castle_cell(0)).garrison_shields = 0
	check(field.board.tile_at(config.resource_cells[0]).owner == -1 and field.board.tile_at(config.castle_cell(0)).garrison_shields == 3, "Copies isolate terrain ownership and shields")
	check(config.create_board().tile_at(config.resource_cells[0]).owner == -1, "Map resources never inherit runtime ownership")
	var bad := config.duplicate(true) as BattlefieldConfig
	bad.resource_cells.append(bad.castle_cell(0))
	check(not bad.validation_error().is_empty(), "Reject overlapping objective and terrain cells")
	bad = BattlefieldConfig.new()
	bad.river_cells = [Vector2i(12, 0)]
	check(not bad.validation_error().is_empty(), "Reject terrain beyond map edges")
	var large := BattlefieldConfig.new()
	large.rows = 14
	large.columns = 18
	var board := large.create_board()
	check(board.contains(Vector2i(13, 17)) and not board.contains(Vector2i(14, 17)) and not board.contains(Vector2i(13, 18)) and not board.contains(Vector2i(-1, 0)), "14x18 bounds and negative edges")
	var rook := board.spawn(catalog.get_unit("ram"), 0, Vector2i(12, 0))
	check(Vector2i(12, 17) not in MovementRules.pseudo_targets(board, rook) and Vector2i(12, 4) in MovementRules.pseudo_targets(board, rook), "Tactical rook stops at four tiles")
	board.tile_at(Vector2i(12, 3)).terrain = BattlefieldTileData.Terrain.RIVER
	check(Vector2i(12, 3) not in MovementRules.pseudo_targets(board, rook) and Vector2i(12, 4) not in MovementRules.pseudo_targets(board, rook), "River blocks sliding destination and path")
	check(not MovementRules.attacked(board, Vector2i(12, 4), 0), "Ground threat ray respects river")
	var pawn := board.spawn(catalog.get_unit("phalanx"), 0, Vector2i(12, 2))
	check(Vector2i(10, 2) in MovementRules.pseudo_targets(board, pawn), "Pawn uses actual starting rank")
	board.tile_at(Vector2i(11, 2)).terrain = BattlefieldTileData.Terrain.IMPASSABLE
	check(MovementRules.pseudo_targets(board, pawn).is_empty(), "Pawn cannot jump over terrain on double step")
	var knight := board.spawn(catalog.get_unit("cavalry"), 0, Vector2i(13, 7))
	check(Vector2i(11, 8) in MovementRules.pseudo_targets(board, knight), "Knight jumps intervening river")
	check(Vector2i(12, 9) in MovementRules.pseudo_targets(board, knight), "Knight reaches clear landing")
	board.tile_at(Vector2i(11, 8)).terrain = BattlefieldTileData.Terrain.RIVER
	check(Vector2i(11, 8) not in MovementRules.pseudo_targets(board, knight), "Knight cannot land in water")
	board = BoardState.new(12, 16)
	var bishop := board.spawn(catalog.get_unit("assassin"), 0, Vector2i(11, 0))
	check(Vector2i(0, 11) not in MovementRules.pseudo_targets(board, bishop) and Vector2i(8, 3) in MovementRules.pseudo_targets(board, bishop), "Bishop diagonal capped at three")
	board.tile_at(Vector2i(8, 3)).terrain = BattlefieldTileData.Terrain.IMPASSABLE
	check(Vector2i(7, 4) not in MovementRules.pseudo_targets(board, bishop), "Bishop ground ray blocked by rock")
	var queen := board.spawn(catalog.get_unit("queen"), 1, Vector2i(0, 15))
	check(Vector2i(11, 15) not in MovementRules.pseudo_targets(board, queen) and Vector2i(4, 15) in MovementRules.pseudo_targets(board, queen), "Queen capped at four")
	var ranged := board.spawn(catalog.get_unit("trebuchet"), 0, Vector2i(5, 2))
	board.tile_at(Vector2i(5, 3)).terrain = BattlefieldTileData.Terrain.RIVER
	check(Vector2i(5, 5) in MovementRules.ranged_targets(board, ranged) and Vector2i(5, 5) not in MovementRules.pseudo_targets(board, ranged), "Ranged geometry crosses water without allowing movement")
	board.spawn(catalog.get_unit("phalanx"), 1, Vector2i(5, 4))
	check(Vector2i(5, 4) in MovementRules.ranged_targets(board, ranged) and Vector2i(5, 5) not in MovementRules.ranged_targets(board, ranged), "Projectile ray stops at first unit")
	var data := catalog.get_unit("ram").duplicate() as UnitData
	data.custom_ability_script = load("res://tests/fixtures/recording_ability.gd")
	field = TacticalField.new(BattlefieldConfig.new())
	var first := field.deploy_unit(data, 0, Vector2i(4, 4))
	var second := field.deploy_unit(data, 0, Vector2i(4, 8))
	var enemy := field.deploy_unit(catalog.get_unit("phalanx"), 1, Vector2i(4, 5))
	check(first.ability != second.ability and first.ability.events == ["deploy"], "Ability instance belongs to each unit")
	field.legal_targets(first.cell)
	clone = field.board.copy()
	check(first.ability.events == ["deploy"] and clone.at(first.cell).ability == null, "Previews and simulation do not execute or share abilities")
	check(not field.move_unit(first.cell, Vector2i(-1, 0)) and first.ability.events == ["deploy"], "Rejected move invokes no hooks")
	check(field.move_unit(first.cell, enemy.cell) and field.board.units.size() == 2, "Valid capture removes defender")
	check(first.ability.events == ["deploy", "capture", "move"], "Capture and movement hooks run once on commit")
	check(first.position_history == [Vector2i(4, 4), Vector2i(4, 5)], "History records committed positions")
	field.notify_turn_end(0)
	check(first.ability.events.back() == "turn_end" and second.ability.events == ["deploy", "turn_end"], "End-turn hook dispatched only through explicit boundary")
	clone = field.board.copy()
	clone.at(first.cell).position_history.append(Vector2i.ZERO)
	check(first.position_history.size() == 2, "Copies isolate position history")
	for id in catalog.entries:
		check(catalog.get_unit(id).validation_error().is_empty(), "Resource variant validates: " + str(id))
	print("TACTICAL FIELD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
