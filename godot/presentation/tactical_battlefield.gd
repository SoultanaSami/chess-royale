extends Node3D
@export var battlefield_config: BattlefieldConfig
var game: TacticalMatch
var field: TacticalField:
	get: return game.field
var board_view: BoardView
var camera_controller: TacticalCameraController
var hud: TacticalHUD
var input_surface: TacticalBoardInput
var selected := BoardState.NONE
var targets: Array[Vector2i] = []
var attack_targets: Array[Vector2i] = []
var formation: Array = []
var selected_slot := -1
var shooting := false
var started := false
var paused := false
var ai_enabled := true
var ai_running := false
var generation := 0
var persistence_enabled := true
var music: MusicDirector

func _ready() -> void:
	assert(battlefield_config != null)
	configure_display()
	get_window().size_changed.connect(configure_display)
	game = TacticalMatch.new(battlefield_config, load_deck())
	board_view = BoardView.new()
	board_view.terrain_board = game.board
	board_view.battlefield_config = battlefield_config
	add_child(board_view)
	camera_controller = TacticalCameraController.new()
	add_child(camera_controller)
	camera_controller.setup(board_view)
	board_view.unit_impact.connect(camera_controller.shake)
	var gallery := CardGallery.new()
	add_child(gallery)
	gallery.build_tactical(game.catalog)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	input_surface = TacticalBoardInput.new()
	canvas.add_child(input_surface)
	input_surface.clicked.connect(on_clicked)
	input_surface.hovered.connect(on_hovered)
	input_surface.formation_selected.connect(select_box)
	input_surface.cancelled.connect(clear_selection)
	input_surface.mouse_exited.connect(func(): board_view.hover_cell(BoardState.NONE))
	input_surface.camera_input.connect(camera_controller._unhandled_input)
	input_surface.card_dropped.connect(deploy)
	input_surface.drop_allowed = func(slot, point): return ready_to_play() and board_view.pick(point) in game.deploy_targets(slot, 0)
	hud = TacticalHUD.new()
	canvas.add_child(hud)
	hud.build(game.catalog, gallery.textures, game.reserves[0])
	hud.start_requested.connect(start_match)
	hud.slot_selected.connect(select_slot)
	hud.end_requested.connect(end_player_turn)
	hud.pause_requested.connect(func(): set_paused(true))
	hud.resume_requested.connect(func(): set_paused(false))
	hud.resign_requested.connect(func():
		set_paused(false)
		game.resign(0)
	)
	hud.restart_requested.connect(open_deck)
	hud.menu_requested.connect(return_to_menu)
	hud.shoot_requested.connect(toggle_shoot)
	hud.music_changed.connect(set_music_volume)
	music = MusicDirector.new()
	add_child(music)
	var settings := ConfigFile.new()
	settings.load("user://settings.cfg")
	var volume := clampf(float(settings.get_value("audio", "music_volume", .35)), 0, 1)
	hud.volume.set_value_no_signal(volume * 100)
	set_music_volume(volume, false)
	music.play_cue("library")
	game.changed.connect(refresh)
	game.event_occurred.connect(on_action)
	refresh()
	camera_controller.controls_enabled = false

func load_deck() -> Array:
	var config := ConfigFile.new()
	if persistence_enabled and config.load("user://tactical_deck.cfg") == OK:
		var value = config.get_value("reserve", "ids", [])
		if value is Array and TacticalCatalog.new().valid_reserve(value):
			return value
	return TacticalCatalog.DEFAULT_RESERVE.duplicate()

func start_match(deck: Array) -> void:
	if not game.catalog.valid_reserve(deck):
		return
	generation += 1
	ai_running = false
	game = TacticalMatch.new(battlefield_config, deck)
	game.changed.connect(refresh)
	game.event_occurred.connect(on_action)
	board_view.terrain_board = game.board
	board_view.reset()
	if persistence_enabled:
		var config := ConfigFile.new()
		config.set_value("reserve", "ids", deck)
		config.save("user://tactical_deck.cfg")
	started = true
	paused = false
	hud.deck_layer.hide()
	hud.pause_layer.hide()
	hud.outcome_layer.hide()
	camera_controller.controls_enabled = true
	camera_controller.board = game.board
	camera_controller.focus_base(0)
	music.play_cue("battle")
	clear_selection()
	refresh()

func open_deck() -> void:
	generation += 1
	started = false
	ai_running = false
	paused = false
	clear_selection()
	hud.outcome_layer.hide()
	hud.pause_layer.hide()
	hud.deck_layer.show()
	camera_controller.controls_enabled = false
	music.play_cue("library")

func ready_to_play() -> bool:
	return started and not paused and not game.finished

func _process(delta: float) -> void:
	if not ready_to_play():
		return
	game.tick(delta)
	game.advance_siege_search()
	if game.config.turn_time_limit > 0:
		hud.update_clock(game)
	if game.turn == 1 and not game.finished and ai_enabled and not ai_running:
		run_ai()

func run_ai() -> void:
	ai_running = true
	var token := generation
	while ready_to_play() and game.turn == 1 and game.cp > 0 and token == generation:
		await get_tree().create_timer(.35).timeout
		if not ready_to_play() or token != generation or game.turn != 1:
			break
		var action := SiegeAI.choose(game)
		if action.is_empty() or not game.execute(action, 1):
			break
	if token == generation:
		if ready_to_play() and game.turn == 1:
			game.end_turn(1)
		ai_running = false

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_ESCAPE and started and not game.finished:
		if not paused and (selected != BoardState.NONE or selected_slot >= 0):
			clear_selection()
		else:
			set_paused(not paused)
	elif ready_to_play():
		if key >= KEY_1 and key <= KEY_5:
			select_slot(key - KEY_1)
		elif key == KEY_SPACE:
			end_player_turn()
		elif key == KEY_G:
			move_formation()
		elif key == KEY_R:
			toggle_shoot()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()

func set_paused(value: bool) -> void:
	if not started or game.finished:
		return
	paused = value
	hud.pause_layer.visible = value
	camera_controller.controls_enabled = not value
	camera_controller.orbiting = false

func clear_selection() -> void:
	selected = BoardState.NONE
	selected_slot = -1
	formation.clear()
	shooting = false
	refresh()

func select_slot(slot: int) -> void:
	if not ready_to_play() or game.deploy_targets(slot, 0).is_empty():
		hud.message.text = "Rekrutierung nicht möglich: Gold, KP und freie Burgfelder prüfen."
		return
	selected = BoardState.NONE
	formation.clear()
	shooting = false
	selected_slot = slot
	refresh()

func deploy(slot: int, point: Vector2) -> void:
	if ready_to_play():
		if not game.execute({"kind": "deploy", "slot": slot, "to": board_view.pick(point)}, 0):
			hud.message.text = game.last_error

func toggle_shoot() -> void:
	var unit := game.board.at(selected)
	if not ready_to_play() or unit == null or unit.team != 0 or unit.definition.ranged_attack_range == 0:
		return
	shooting = not shooting
	refresh()

func on_clicked(point: Vector2, shift: bool) -> void:
	if not ready_to_play(): return
	var cell := board_view.pick(point)
	var unit := game.board.at(cell)
	if shift and unit != null and unit.team == 0 and unit.chess_type == "PAWN":
		selected_slot = -1
		shooting = false
		if formation.is_empty() and selected != BoardState.NONE:
			var previous := game.board.at(selected)
			if previous != null and previous.team == 0 and previous.chess_type == "PAWN": formation.append(selected)
		if cell in formation: formation.erase(cell)
		else: formation.append(cell)
		selected = formation[0] if not formation.is_empty() else BoardState.NONE
		refresh()
		return
	if selected_slot >= 0 and cell in targets:
		deploy(selected_slot, point)
		return
	if formation.size() > 1 and cell in targets:
		move_formation()
		return
	if selected != BoardState.NONE and cell in targets:
		var shooter := game.board.at(selected)
		var fire := shooting or (cell in attack_targets and shooter != null and cell in MovementRules.ranged_targets(game.board, shooter))
		if game.execute({"kind": "shoot" if fire else "move", "from": selected, "to": cell}, 0):
			if not fire: selected = cell
			formation.clear()
			refresh()
		return
	selected_slot = -1
	shooting = false
	formation.clear()
	selected = cell if unit != null else BoardState.NONE
	refresh()

func select_box(rect: Rect2) -> void:
	if not ready_to_play() or game.turn != 0: return
	formation.clear()
	for unit in game.board.units.values():
		if unit.team == 0 and unit.chess_type == "PAWN" and rect.has_point(board_view.camera.unproject_position(board_view.cell_position(unit.cell) + Vector3(0, .5, 0))):
			formation.append(unit.cell)
	selected_slot = -1
	shooting = false
	selected = formation[0] if not formation.is_empty() else BoardState.NONE
	refresh()

func move_formation() -> void:
	if not ready_to_play(): return
	var cells := formation.duplicate()
	if game.execute({"kind": "formation", "cells": cells}, 0):
		formation.clear()
		for cell in cells: formation.append(cell + Vector2i(-1, 0))
		selected = formation[0]
		refresh()
	else:
		hud.message.text = game.last_error

func end_player_turn() -> void:
	if ready_to_play() and game.end_turn(0):
		clear_selection()

func on_hovered(point: Vector2) -> void:
	if not ready_to_play() or camera_controller.orbiting: return
	var cell := board_view.pick(point)
	board_view.select_tactical(selected, targets, attack_targets, cell)
	board_view.hover_cell(cell)
	board_view.clear_children(board_view.preview_layer)
	if selected != BoardState.NONE and cell in targets and selected_slot < 0:
		var unit := game.board.at(selected)
		var relocate := not shooting and not (cell in attack_targets and unit != null and cell in MovementRules.ranged_targets(game.board,unit))
		board_view.preview_destination(selected,cell,relocate)
	mark_formation()

func mark_formation() -> void:
	if formation.size() > 1:
		for view in board_view.units.values():
			view.set_selected(view.last_cell in formation)

func refresh() -> void:
	if hud == null: return
	board_view.clear_children(board_view.preview_layer)
	board_view.sync_board(game.board)
	board_view.sync_objectives(game.board, game.siege)
	targets.clear()
	attack_targets.clear()
	if selected_slot >= 0:
		targets = game.deploy_targets(selected_slot, 0)
	elif formation.size() > 1:
		if game.can_act(0) and TacticalCommands.formation_valid(game.board, formation, 0):
			for cell in formation: targets.append(cell + Vector2i(-1, 0))
	elif selected != BoardState.NONE:
		var unit := game.board.at(selected)
		if unit == null:
			selected = BoardState.NONE
		elif shooting and game.can_act(0) and unit.team == 0:
			for cell in MovementRules.ranged_targets(game.board, unit):
				if game.board.at(cell) != null and game.board.at(cell).team != 0: targets.append(cell)
		else:
			targets = game.legal_targets(selected)
	var chosen_unit := game.board.at(selected)
	if chosen_unit != null and chosen_unit.team == 0 and game.can_act(0) and formation.size() < 2:
		for cell in targets:
			if game.board.at(cell) != null and game.board.at(cell).team != 0: attack_targets.append(cell)
		for cell in MovementRules.ranged_targets(game.board, chosen_unit):
			if game.board.at(cell) != null and game.board.at(cell).team != 0:
				if cell not in attack_targets: attack_targets.append(cell)
				if cell not in targets: targets.append(cell)
	board_view.select_tactical(selected, targets, attack_targets)
	mark_formation()
	hud.sync(game, selected_slot, game.board.at(selected), shooting, ready_to_play())
	if formation.size() > 1:
		hud.selected_info.text = "Phalanx: %d Bauern · G oder markiertes Feld · 1 KP" % formation.size() if not targets.is_empty() else "Formation braucht eine lückenlose Bauernreihe und freie Felder davor."
	if game.finished:
		camera_controller.controls_enabled = false
		hud.pause_layer.hide()

func on_action(action: Dictionary) -> void:
	if action.kind == "deploy": board_view.pending_deploy.append(action.to)
	if action.kind == "shoot":
		board_view.projectile(action.from, action.to)

func set_music_volume(value: float, save: bool = true) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(MusicDirector.MUSIC_BUS), value)
	if save and persistence_enabled:
		var settings := ConfigFile.new()
		settings.load("user://settings.cfg")
		settings.set_value("audio", "music_volume", value)
		settings.save("user://settings.cfg")

func return_to_menu() -> void:
	generation += 1
	get_tree().change_scene_to_file("res://scenes/war_room.tscn")

func configure_display() -> void:
	get_window().content_scale_size = get_window().size
