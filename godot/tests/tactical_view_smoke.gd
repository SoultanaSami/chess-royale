extends SceneTree
var checks := 0
var failures := 0
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func frames(count: int = 4) -> void:
	for i in range(count): await process_frame
func motion(position: Vector2, held: bool = false, relative := Vector2.ZERO) -> void:
	Input.warp_mouse(root.get_final_transform() * position)
	await create_timer(.04).timeout
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await frames()
func mouse(position: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * position
	event.button_index = button
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	event.shift_pressed = shift
	Input.parse_input_event(event)
	await frames()
func click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	await motion(position)
	await mouse(position, true, button, shift)
	await mouse(position, false, button, shift)
func key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames()
func button(text: String) -> Button:
	for node in scene.hud.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null
func point(cell: Vector2i, height: float = 0) -> Vector2:
	return scene.board_view.camera.unproject_position(scene.board_view.cell_position(cell) + Vector3(0, height, 0))
func fixture() -> void:
	scene.ai_enabled = false
	scene.game.board.units.clear()
	scene.board_view.reset()
	scene.game.turn = 0
	scene.game.cp = 3
	scene.game.gold[0] = 10
	scene.game.phase = TacticalMatch.Phase.ACTION
	scene.game.refresh_siege()
	scene.clear_selection()
	await frames()
func place(id: String, team: int, at: Vector2i) -> void:
	scene.game.board.spawn(scene.game.catalog.get_unit(id), team, at)
func drag_card(slot: int, destination: Vector2) -> void:
	var origin: Vector2 = scene.hud.cards[slot].get_global_rect().get_center()
	await motion(origin)
	await mouse(origin, true)
	await motion(origin + Vector2(0, -35), true, Vector2(0,-35))
	await motion(destination, true, destination - origin)
	await mouse(destination, false)
	await frames()
func run() -> void:
	root.size = Vector2i(1440, 810)
	scene = load("res://scenes/tactical_battlefield.tscn").instantiate()
	scene.persistence_enabled = false
	scene.ai_enabled = false
	root.add_child(scene)
	current_scene = scene
	root.grab_focus()
	scene.camera_controller.edge_pan_enabled = false
	await create_timer(.7).timeout
	check(scene.hud.deck_layer.visible and not scene.started, "Match opens with deck selection")
	check(scene.hud.selectors.size() == 5 and scene.hud.selectors[3].item_count == 3, "Five role slots expose rook variants")
	scene.hud.selectors[3].select(1)
	scene.hud.selectors[3].item_selected.emit(1)
	await frames()
	await click(button("SCHLACHT BEGINNEN").get_global_rect().get_center())
	await create_timer(.25).timeout
	check(scene.started and not scene.hud.deck_layer.visible and scene.game.reserves[0][3] == "trebuchet", "Chosen reserve starts match")
	check(scene.game.board.units.size() == 8 and scene.board_view.units.size() == 8, "Eight vanguard models")
	check(scene.camera_controller.distance < scene.camera_controller.home_distance * .5, "Default camera frames the player base closely")
	scene.camera_controller.reset_view()
	await frames()
	for cell in [Vector2i(0, 5), Vector2i(0, 31), Vector2i(23, 0), Vector2i(23, 29)]:
		check(root.get_visible_rect().has_point(point(cell)), "Large map corner visible in overview")
		check(scene.board_view.pick(point(cell)) == cell, "Large map corner picking")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/schachschlachtfeld-cliffs-ui.png")
	scene.camera_controller.focus_base(0)
	await frames()
	await key(KEY_2)
	await key(KEY_2, false)
	check(scene.selected_slot == 1 and not scene.targets.is_empty(), "Hotkey selects reserve and deployment runes")
	await click(point(Vector2i(19, 4)))
	check(scene.game.board.at(Vector2i(19, 4)) != null and scene.game.cp == 2 and scene.game.gold[0] == 7, "Hotkey plus native board click deploys and pays")
	await click(point(Vector2i(18, 6)), MOUSE_BUTTON_RIGHT)
	check(scene.selected_slot == -1, "Right-click cancels deployment")
	await fixture()
	await drag_card(3, point(Vector2i(19, 4)))
	check(scene.game.board.at(Vector2i(19, 4)) != null and scene.game.board.at(Vector2i(19, 4)).variant_id == "trebuchet", "Native card drag deploys chosen variant")
	check(scene.game.gold[0] == 6 and scene.game.cp == 2, "Drag deployment spends exactly one action and card cost")
	await drag_card(0, point(scene.battlefield_config.river_cells[0]))
	check(scene.game.gold[0] == 6 and scene.game.cp == 2, "Invalid drop spends nothing")
	await fixture()
	for col in [5, 6, 7]: place("phalanx", 0, Vector2i(18, col))
	scene.refresh()
	await create_timer(.2).timeout
	await click(point(Vector2i(18, 5), .55))
	await click(point(Vector2i(18, 6), .55), MOUSE_BUTTON_LEFT, true)
	await click(point(Vector2i(18, 7), .55), MOUSE_BUTTON_LEFT, true)
	check(scene.formation.size() == 3 and scene.targets.size() == 3, "Shift-click forms adjacent pawn line")
	await key(KEY_G)
	await key(KEY_G, false)
	check(scene.game.cp == 2 and scene.game.board.at(Vector2i(17, 5)) != null and scene.game.board.at(Vector2i(17, 7)) != null, "Formation hotkey advances entire line for one CP")
	await create_timer(.2).timeout
	var first := point(Vector2i(17, 5), .5) - Vector2(16, 25)
	var last := point(Vector2i(17, 7), .5) + Vector2(16, 25)
	await motion(first)
	await mouse(first, true)
	await motion(last, true, last - first)
	await mouse(last, false)
	check(scene.formation.size() == 3, "Box selection selects pawn line")
	await fixture()
	place("trebuchet", 0, Vector2i(18, 3))
	place("phalanx", 1, Vector2i(18, 6))
	scene.refresh()
	await create_timer(.2).timeout
	await click(point(Vector2i(18, 3), .6))
	check(Vector2i(18,6) in scene.attack_targets and scene.targets.size() > scene.attack_targets.size(), "Selection separates blue moves from red attacks")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/cliffs-move-attack.png")
	await key(KEY_R)
	await key(KEY_R, false)
	check(scene.shooting and Vector2i(18, 6) in scene.targets, "R activates valid ranged targets")
	await click(point(Vector2i(18, 6), .5))
	check(scene.game.board.at(Vector2i(18, 6)) == null and scene.game.board.at(Vector2i(18, 3)) != null and scene.game.cp == 2, "Native ranged command removes target without moving attacker")
	var distance: float = scene.camera_controller.distance
	await click(root.get_visible_rect().size * .5, MOUSE_BUTTON_WHEEL_UP)
	check(scene.camera_controller.distance < distance, "Wheel zoom over input surface")
	var center := root.get_visible_rect().size * .5
	await mouse(center, true, MOUSE_BUTTON_MIDDLE)
	await motion(center + Vector2(40,15), false, Vector2(40,15))
	await mouse(center, false, MOUSE_BUTTON_MIDDLE)
	check(absf(scene.camera_controller.yaw) > .05 and not scene.camera_controller.orbiting, "Middle drag orbit and release")
	var old_focus: Vector3 = scene.camera_controller.focus
	await key(KEY_W)
	await create_timer(.12).timeout
	await key(KEY_W, false)
	check(scene.camera_controller.focus.distance_to(old_focus) > .1, "WASD pans")
	scene.camera_controller.reset_view()
	scene.camera_controller.edge_pan_enabled = true
	old_focus = scene.camera_controller.focus
	await motion(Vector2(2, root.get_visible_rect().size.y * .5))
	await create_timer(.12).timeout
	check(scene.camera_controller.focus.x < old_focus.x - .1, "Edge-pan recognizes board input surface")
	scene.camera_controller.edge_pan_enabled = false
	scene.camera_controller.reset_view()
	scene.ai_enabled = true
	await key(KEY_SPACE)
	await key(KEY_SPACE, false)
	await create_timer(1.8).timeout
	check(scene.game.turn == 0 and scene.game.round_number >= 2, "Space passes turn and AI completes its CP turn")
	scene.end_player_turn()
	scene.set_paused(true)
	var paused_cp: int = scene.game.cp
	await create_timer(.6).timeout
	check(scene.hud.pause_layer.visible and scene.game.cp == paused_cp, "Pause stops pending AI commands")
	scene.set_paused(false)
	await frames()
	scene.start_match(TacticalCatalog.DEFAULT_RESERVE)
	await create_timer(.7).timeout
	check(scene.game.turn == 0 and scene.game.cp == 3 and scene.game.board.units.size() == 8, "Restart invalidates old AI coroutine")
	await fixture()
	place("ram", 1, Vector2i(20, 8))
	scene.game.board.tile_at(Vector2i(20, 4)).garrison_shields = 1
	scene.game.cp = 0
	scene.game.refresh_siege()
	scene.refresh()
	check(scene.hud.enemy_status.text.contains("BELAGERT") and scene.board_view.check_layer.get_child_count() > 0, "Siege visible on castle and HUD")
	await click(scene.hud.end_button.get_global_rect().get_center())
	check(scene.game.finished and scene.hud.outcome_layer.visible and scene.hud.outcome_title.text == "NIEDERLAGE", "Shield defeat shows result screen")
	check(scene.hud.end_button.disabled and scene.hud.cards[0].disabled, "Finished match disables commands")
	await click(button("NEUE SCHLACHT").get_global_rect().get_center())
	check(scene.hud.deck_layer.visible and not scene.started, "New battle reopens deck selection")
	scene.return_to_menu()
	await create_timer(.6).timeout
	check(current_scene.main_menu.tactical_button.visible, "Return to main menu")
	current_scene.queue_free()
	await frames()
	await create_timer(.2).timeout
	print("TACTICAL VIEW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
