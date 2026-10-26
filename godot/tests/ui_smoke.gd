extends SceneTree
## Real scene checks with native mouse and touch input at phone resolutions.
var checks: int = 0
var failures: int = 0
var scene: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func wait_frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func motion(pos: Vector2, pressed: bool = false, relative := Vector2.ZERO) -> void:
	Input.warp_mouse(root.get_final_transform() * pos)
	# Native drag hit testing consults the window cursor, not only injected event coordinates.
	await create_timer(0.04).timeout
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	await wait_frames()

func mouse_button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	await wait_frames()

func click(pos: Vector2) -> void:
	await motion(pos)
	await mouse_button(pos, true)
	await mouse_button(pos, false)

func control_click(control: Control) -> void:
	await wait_frames()
	await click(control.get_global_rect().get_center())

func square(cell: Vector2i) -> Vector2:
	return scene.input_surface.global_position + scene.board_view.camera.unproject_position(BoardView.world_position(cell))

func tap(pos: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = pos
	event.pressed = true
	Input.parse_input_event(event)
	await wait_frames()
	event = InputEventScreenTouch.new()
	event.index = 0
	event.position = pos
	event.pressed = false
	Input.parse_input_event(event)
	await wait_frames()

func bare_position() -> void:
	scene.start_match(Catalog.DEFAULT_DECK)
	scene.game.board = BoardState.new()
	scene.board_view.reset()

func place(id: String, side: int, cell: Vector2i) -> UnitState:
	return scene.game.board.spawn(scene.catalog.get_piece(id),side,cell)

func shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/schachschlachtfeld-" + name + ".png")

func run() -> void:
	root.size = Vector2i(390,844)
	scene = load("res://scenes/war_room.tscn").instantiate()
	scene.persistence_enabled = false
	root.add_child(scene)
	await create_timer(0.6).timeout
	check(scene.main_menu.visible and scene.game == null,"Main menu before first match")
	check(scene.music_director.current_cue == "library" and scene.music_director.is_playing(),"Library music starts in the main menu")
	await shot("menu")
	await control_click(scene.main_menu.deck_button)
	check(scene.hud.deck_layer.visible and scene.hud.chosen_deck.size() == 16,"Editor keeps full existing test formation")
	check(scene.hud.slot_rows[0].visible and scene.hud.slot_rows[7].visible and not scene.hud.slot_rows[1].visible,"Two independent rook slots")
	await control_click(scene.hud.slot_selectors[0])
	var popup: PopupMenu = scene.hud.slot_selectors[0].get_popup()
	await click(Vector2(popup.position) + Vector2(popup.size)*0.5)
	check(scene.hud.chosen_deck[0] == "trebuchet","Native variant dropdown changes left rook")
	check(scene.hud.chosen_deck[7] == "golem","Right rook remains unchanged")
	scene.hud.change_variant(8,"queen")
	check(scene.hud.chosen_deck[8] == "phalanx","Editor rejects queen in pawn slot")
	await control_click(scene.hud.tabs.get_node("SPELL"))
	check(scene.hud.spell_rows.size() == 2 and scene.hud.spell_rows[0].visible and scene.hud.spell_rows[1].visible,"Fesseln and Schutz visible in dedicated section")
	check(not scene.hud.confirm_button.visible and scene.hud.chosen_deck.size() == 16,"Spell descriptions have no invented selection mechanic")
	check(scene.hud.spell_rows[0].get_child(0).get_child(0).text == "Fesseln" and scene.hud.spell_rows[1].get_child(0).get_child(0).text == "Schutz","Exact requested spell names")
	await control_click(scene.hud.tabs.get_node("ROOK"))
	await control_click(scene.hud.confirm_button)
	check(scene.main_menu.visible and scene.game == null,"Save formation returns to menu")
	await control_click(scene.main_menu.play_button)
	check(scene.game.board.units.size() == 32 and scene.game.board.at(Vector2i(7,0)).variant_id == "trebuchet","Selected variant appears in full starting army")
	check(scene.music_director.current_cue == "battle" and scene.music_director.is_playing(),"Battle music starts when a match begins")
	check(not scene.game.has_method("play_card") and not scene.game.has_method("end_turn"),"No in-match spells, deployment or pass command")
	scene.open_deck()
	check(scene.screen == scene.Screen.BATTLE,"Deck locked during battle")
	scene.open_main_menu()
	check(scene.main_menu.deck_button.disabled,"Deck also locked while paused")
	await control_click(scene.main_menu.abandon_button)
	check(scene.game.finished and scene.game.winner == 1 and scene.hud.outcome.visible and scene.game.result_reason == "Aufgabe","Resignation visibly ends game with opponent win")
	check(scene.game.board.king(0) != null,"King survives resignation")
	scene.open_main_menu()
	check(not scene.main_menu.deck_button.disabled,"Ended game unlocks deck")
	for resolution in [Vector2i(390,844),Vector2i(844,390),Vector2i(360,800),Vector2i(375,667),Vector2i(360,640)]:
		root.size = resolution
		await create_timer(0.2).timeout
		scene.start_match(Catalog.DEFAULT_DECK)
		await wait_frames(5)
		check(scene.hud.menu_button.size.y >= 48,"Touch menu remains at least 48 logical pixels")
		for row in range(8):
			for col in range(8):
				check(scene.input_surface.get_global_rect().has_point(square(Vector2i(row,col))),"All 64 squares visible on phone")
		check(not scene.hud.details.get_global_rect().intersects(scene.input_surface.get_global_rect()),"Inspector stays outside board")
		check(not scene.hud.hint_label.get_global_rect().intersects(scene.hud.details.get_global_rect()),"Status does not overlap inspector")
		check(Rect2(Vector2.ZERO,Vector2(resolution)).encloses(scene.hud.menu_button.get_global_rect()),"Menu remains on screen")
	root.size = Vector2i(390,844)
	await create_timer(0.2).timeout
	scene.start_match(Catalog.DEFAULT_DECK)
	await wait_frames(5)
	await physics_frame
	var knight = scene.game.board.at(Vector2i(7,1))
	await tap(square(Vector2i(7,1)))
	check(scene.selected == Vector2i(7,1) and scene.targets.size() == 2,"Native touch selects legal knight destinations")
	await tap(square(Vector2i(5,0)))
	await create_timer(0.4).timeout
	check(knight.cell == Vector2i(5,0) and scene.game.ply_count == 2 and scene.game.turn == 0,"One touch move and exactly one AI reply")
	check(scene.selected == BoardState.NONE,"No retained selection enabling a second action")
	# Immediate authoritative turn switch and pause before the scheduled AI reply.
	check(scene.game.move_unit(Vector2i(6,4),Vector2i(4,4)),"Second player move legal")
	check(scene.game.turn == 1,"Turn switches before any animation or timer")
	scene.open_main_menu()
	var count: int = scene.game.ply_count
	await create_timer(0.4).timeout
	check(scene.game.ply_count == count and scene.game.turn == 1,"Opponent does not move in pause menu")
	await tap(scene.main_menu.resume_button.get_global_rect().get_center())
	await create_timer(0.4).timeout
	check(scene.game.ply_count == count+1 and scene.game.turn == 0,"Resume schedules exactly one reply")
	scene.start_match(Catalog.DEFAULT_DECK)
	scene.game.move_unit(Vector2i(6,4),Vector2i(4,4))
	scene.open_main_menu()
	scene.start_match(Catalog.DEFAULT_DECK)
	await create_timer(0.4).timeout
	check(scene.game.turn == 0 and scene.game.ply_count == 0,"Old AI request cannot mutate new match")
	# Persistent check marker and legal-only board highlights.
	bare_position()
	place("guard",0,Vector2i(7,4))
	place("guard",1,Vector2i(0,7))
	place("ram",1,Vector2i(0,4))
	place("ram",0,Vector2i(6,0))
	scene.refresh()
	await wait_frames(5)
	await physics_frame
	check("SCHACH" in scene.hud.position_label.text and "Schach" in scene.hud.hint_label.text,"Check is explicit in HUD")
	var marker_count: int = scene.board_view.check_layer.get_child_count()
	check(marker_count > 0,"Checked king has persistent 3D marker")
	await tap(square(Vector2i(6,0)))
	check(Vector2i(6,4) in scene.targets and not Vector2i(5,0) in scene.targets,"Touch highlights only moves resolving check")
	scene.clear_selection()
	check(scene.board_view.check_layer.get_child_count() == marker_count,"Deselecting does not remove check marker")
	await shot("check")
	# Native touch castling moves both pieces in one turn; pause before reply.
	bare_position()
	var king := place("guard",0,Vector2i(7,4))
	king.castle_eligible = true
	var rook := place("trebuchet",0,Vector2i(7,7))
	rook.castle_eligible = true
	place("guard",1,Vector2i(0,4))
	scene.refresh()
	await wait_frames(5)
	await physics_frame
	await tap(square(Vector2i(7,4)))
	check(Vector2i(7,6) in scene.targets,"Castling destination is highlighted")
	await tap(square(Vector2i(7,6)))
	scene.open_main_menu()
	check(king.cell == Vector2i(7,6) and rook.cell == Vector2i(7,5),"Native touch castling moves both models")
	# Promotion is a real choice, with no mutation before selection.
	bare_position()
	place("guard",0,Vector2i(7,7))
	place("guard",1,Vector2i(0,7))
	var pawn := place("phalanx",0,Vector2i(1,0))
	scene.refresh()
	await wait_frames(5)
	await physics_frame
	await tap(square(Vector2i(1,0)))
	await tap(square(Vector2i(0,0)))
	check(scene.hud.promotion_layer.visible and scene.game.ply_count == 0,"Promotion dialog pauses command before committing move")
	await shot("promotion")
	await tap(scene.hud.promotion_buttons["cavalry"].get_global_rect().get_center())
	scene.open_main_menu()
	check(pawn.chess_type == "KNIGHT" and pawn.cell == Vector2i(0,0),"Touch underpromotion works")
	# Mate without capture, and visible result instead of a stalled opponent.
	scene.start_match(Catalog.DEFAULT_DECK)
	scene.open_main_menu()
	scene.game.move_unit(Vector2i(6,5),Vector2i(5,5))
	scene.game.move_unit(Vector2i(1,4),Vector2i(3,4))
	scene.game.move_unit(Vector2i(6,6),Vector2i(4,6))
	scene.game.move_unit(Vector2i(0,3),Vector2i(4,7))
	scene.show_battle()
	scene.refresh()
	check(scene.hud.outcome.visible and scene.hud.outcome_reason.text == "Schachmatt","Checkmate result is visible")
	check(scene.game.board.king(0) != null and scene.game.board.king(1) != null,"Neither king is removed at match end")
	await shot("mate")
	await tap(scene.hud.outcome.get_child(0).get_node("Rematch").get_global_rect().get_center())
	check(not scene.game.finished and scene.game.board.units.size() == 32 and scene.game.turn == 0,"Rematch restores setup and castling rights")
	await wait_frames(5)
	await shot("battle")
	# Real phone spell view: descriptions visible, no selectable charges or costs.
	scene.open_main_menu()
	scene.abandon_match()
	scene.open_main_menu()
	scene.open_deck()
	await tap(scene.hud.tabs.get_node("SPELL").get_global_rect().get_center())
	await wait_frames(5)
	await shot("spells")
	print("UI: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await wait_frames(3)
	quit(1 if failures else 0)
