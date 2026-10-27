extends SceneTree
var checks := 0
var failures := 0
var catalog := TacticalCatalog.new()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func empty_game() -> TacticalMatch:
	var config := BattlefieldConfig.new()
	config.rows = 8
	config.columns = 8
	config.starting_gold = 0
	config.base_income = 0
	var game := TacticalMatch.new(config)
	game.board.units.clear()
	return game
func place(game: TacticalMatch, id: String, team: int, cell: Vector2i) -> UnitState:
	return game.board.spawn(catalog.get_unit(id), team, cell)
func finish_search(search: SiegeSearch) -> void:
	for i in range(500):
		search.advance(5000)
		if search.done: return
	check(false, "Small defensive search must terminate")
func run() -> void:
	var config := load("res://data/battlefields/ashen_cliffs.tres") as BattlefieldConfig
	check(config.validation_error().is_empty(), "Valley terrain validates")
	var game := TacticalMatch.new(config)
	check(game.board.rows == 24 and game.board.columns == 32 and game.board.tiles.size() == 768, "Large 24x32 map")
	check(config.resource_cells.size() == 5 and game.mines_owned(0) == 0, "Five neutral gold mines")
	check(game.cp == 3 and game.gold == [10, 10] and game.board.units.size() == 8, "Starting resources, CP and vanguards")
	check(not catalog.valid_reserve(["queen", "cavalry", "assassin", "ram", "phalanx"]), "Reserve roles cannot be swapped")
	check(catalog.valid_reserve(["phalanx", "cavalry", "assassin", "trebuchet", "queen"]), "Rook variant can be chosen")
	var cell := Vector2i(19, 4)
	check(not game.execute({"kind": "deploy", "slot": 9, "to": cell}, 0), "Reject invalid card slot")
	check(not game.execute({"kind": "deploy", "slot": 0, "to": cell}, 1), "Reject inactive side")
	check(not game.execute({"kind": "deploy", "slot": 0, "to": Vector2i(12, 12)}, 0), "Reject deployment away from castle")
	check(not game.execute({"kind": "deploy", "slot": 0, "to": Vector2i(20, 4)}, 0), "Castle cannot be occupied")
	check(game.cp == 3 and game.gold[0] == 10 and game.board.units.size() == 8, "Invalid commands spend nothing")
	game.gold[0] = 0
	check(not game.execute({"kind": "deploy", "slot": 0, "to": cell}, 0) and game.cp == 3, "Insufficient gold does not spend CP")
	game.gold[0] = 10
	check(game.execute({"kind": "deploy", "slot": 0, "to": cell}, 0), "Deploy at castle")
	check(game.cp == 2 and game.gold[0] == 9 and game.board.at(cell) != null, "Atomic CP and gold debit")
	check(game.execute({"kind": "move", "from": cell, "to": Vector2i(18, 4)}, 0), "New deployment can act")
	check(game.execute({"kind": "move", "from": Vector2i(18, 4), "to": Vector2i(17, 4)}, 0), "Same unit may spend another CP")
	check(game.cp == 0 and not game.execute({"kind": "move", "from": Vector2i(17, 4), "to": Vector2i(16, 4)}, 0), "Zero CP rejects further actions")
	check(SiegeAI.choose(game).is_empty(), "AI cannot act without CP")
	check(game.end_turn(0) and game.turn == 1 and game.cp == 3 and game.gold[1] == 12, "Turn switch resets CP and grants income")
	check(not game.end_turn(0) and game.gold[1] == 12, "Repeated stale end turn cannot grant extra income")
	game.end_turn(1)
	check(game.turn == 0 and game.round_number == 2 and game.gold[0] == 11, "New round starts with correct budget")
	game.board.units.clear()
	var mine := Vector2i(14, 7)
	place(game, "phalanx", 0, mine)
	var old_gold := game.gold[0]
	game.end_turn(0)
	check(game.board.tile_at(mine).owner == 0 and game.gold[0] == old_gold, "Occupying mine captures it only at turn end")
	game.end_turn(1)
	check(game.gold[0] == old_gold + 4 and game.income(0) == 4, "Mine pays next owner turn alongside base income")
	game.board.units.clear()
	place(game, "phalanx", 1, mine)
	game.end_turn(0)
	check(game.board.tile_at(mine).owner == 0, "Enemy occupation waits for enemy turn end")
	game.end_turn(1)
	check(game.board.tile_at(mine).owner == 1 and game.income(0) == 2 and game.income(1) == 4, "Mine changes hands and income follows owner")
	game = empty_game()
	var line: Array = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)]
	for at in line: place(game, "phalanx", 0, at)
	check(not game.execute({"kind": "formation", "cells": [line[0], line[2]]}, 0), "Phalanx must be contiguous")
	game.board.tile_at(Vector2i(4, 3)).terrain = BattlefieldTileData.Terrain.RIVER
	check(not game.execute({"kind": "formation", "cells": line}, 0) and game.board.at(line[0]) != null and game.cp == 3, "Blocked formation is rejected atomically")
	game.board.tile_at(Vector2i(4, 3)).terrain = BattlefieldTileData.Terrain.STANDARD
	check(game.execute({"kind": "formation", "cells": line}, 0) and game.cp == 2, "Three pawns advance for one CP")
	for at in line: check(game.board.at(at + Vector2i(-1, 0)) != null and game.board.at(at) == null, "Every formation member advances")
	game = empty_game()
	place(game, "trebuchet", 0, Vector2i(3, 1))
	place(game, "ram", 1, Vector2i(3, 4))
	game.board.tile_at(Vector2i(3, 2)).terrain = BattlefieldTileData.Terrain.RIVER
	check(game.execute({"kind": "shoot", "from": Vector2i(3, 1), "to": Vector2i(3, 4)}, 0), "Ranged attack crosses river")
	check(game.board.at(Vector2i(3, 4)) == null and game.board.at(Vector2i(3, 1)) != null and game.cp == 2, "Shot removes target without moving attacker")
	place(game, "phalanx", 0, Vector2i(3, 3))
	check(not game.execute({"kind": "shoot", "from": Vector2i(3, 1), "to": Vector2i(3, 3)}, 0), "Friendly fire rejected")
	game = empty_game()
	place(game, "ram", 1, Vector2i(4, 4))
	game.refresh_siege()
	check(game.siege[0], "Attack ray triggers castle siege")
	check(Vector2i(7, 4) not in MovementRules.pseudo_targets(game.board, game.board.at(Vector2i(4, 4))), "Castle is attacked, never captured as a unit")
	var defender := place(game, "phalanx", 0, Vector2i(6, 4))
	game.refresh_siege()
	check(not game.siege[0], "Blocking attack ray lifts siege")
	game.board.remove(defender)
	game.refresh_siege()
	game.cp = 0
	game.end_turn(0)
	check(not game.finished and game.board.tile_at(Vector2i(7, 4)).garrison_shields == 2, "Unresolved siege costs one shield, not immediate zero-CP mate")
	game.end_turn(1)
	game.end_turn(0)
	game.end_turn(1)
	game.end_turn(0)
	check(game.finished and game.winner == 1 and game.result_reason == "Burg gefallen", "Three failed defenses lose the castle")
	check(not game.end_turn(1) and not game.execute({"kind": "deploy", "slot": 0, "to": Vector2i(1, 4)}, 1), "Finished match rejects all commands")
	game = empty_game()
	place(game, "cavalry", 1, Vector2i(5, 3))
	game.refresh_siege()
	for i in range(10): game.advance_siege_search()
	check(game.finished and game.winner == 1 and game.result_reason.begins_with("Schachmatt"), "Proven absence of any defense wins by mate")
	game = empty_game()
	place(game, "ram", 1, Vector2i(4, 4))
	place(game, "cavalry", 0, Vector2i(6, 1))
	var search := SiegeSearch.new(game.board, 0, game.reserves[0], 0, 3, catalog)
	finish_search(search)
	check(search.done and search.defensible and search.solution.size() >= 2, "Mate search finds a multiple-action knight defense")
	var copy := game.board.copy(false)
	for action in search.solution: TacticalCommands.apply(copy, action, 0, game.reserves[0], catalog)
	check(TacticalCommands.threats(copy, 0).is_empty() and not TacticalCommands.threats(game.board, 0).is_empty(), "Search solution resolves siege without mutating live board")
	game.board.units.clear()
	place(game, "ram", 1, Vector2i(4, 4))
	search = SiegeSearch.new(game.board, 0, game.reserves[0], 1, 3, catalog)
	finish_search(search)
	check(search.defensible and search.solution[0].kind == "deploy", "Affordable deployment is a legal siege defense")
	game = empty_game()
	var promoted := place(game, "phalanx", 0, Vector2i(1, 2))
	check(game.execute({"kind": "move", "from": Vector2i(1, 2), "to": Vector2i(0, 2)}, 0), "Pawn reaches opposite map edge")
	check(promoted.chess_type == "QUEEN" and promoted.definition.chess_role == UnitData.ChessRole.QUEEN and game.cp == 2, "Promotion updates Resource and consumes no extra CP")
	game.resign(0)
	check(game.finished and game.winner == 1 and game.result_reason == "Aufgabe", "Resignation has a visible result")
	game = TacticalMatch.new(config)
	var successful := 0
	for turn in range(10):
		for action_index in range(config.max_cp):
			if game.finished: break
			var action := SiegeAI.choose(game)
			if action.is_empty(): break
			if game.execute(action, game.turn): successful += 1
			else: check(false, "AI chose an illegal action")
			game.advance_siege_search()
		if game.finished: break
		game.end_turn(game.turn)
	check(successful >= 12 and game.gold[0] >= 0 and game.gold[1] >= 0, "Two AIs play multiple full turns on the real map without overspending")
	check(game.mines_owned(0) + game.mines_owned(1) > 0, "AI captures real gold-mine objectives")
	var timed := BattlefieldConfig.new()
	timed.turn_time_limit = 5
	game = TacticalMatch.new(timed)
	game.tick(4)
	check(game.turn == 0 and is_equal_approx(game.remaining_time, 1), "Configured clock counts down")
	game.tick(1)
	check(game.turn == 1 and game.cp == 3 and is_equal_approx(game.remaining_time, 5), "Timer expiry ends turn and resets next clock")
	game.tick(-20)
	check(is_equal_approx(game.remaining_time, 5), "Clock rejects negative elapsed time")
	game.resign(0)
	game.tick(100)
	check(game.turn == 1 and is_equal_approx(game.remaining_time, 5), "Finished game stops clock")
	print("TACTICAL MATCH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
