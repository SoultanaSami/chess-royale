extends Node3D
## UI uses the same legal commands as AI. Match state changes turns synchronously.
enum Screen { MAIN, DECK, BATTLE }
const OPPONENT_INTERVAL := 0.16
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MUSIC_VOLUME := 0.35
var screen: Screen = Screen.MAIN
var catalog := Catalog.new()
var game: GameManager
var board_container: SubViewportContainer
var board_viewport: SubViewport
var ui_root: Control
var board_view: BoardView
var library: LibraryView
var main_menu: MainMenu
var hud: WarRoomHUD
var input_surface: BoardInput
var gallery: CardGallery
var selected := BoardState.NONE
var targets: Array[Vector2i] = []
var deck: Array = Catalog.DEFAULT_DECK.duplicate()
var match_generation: int = 0
var ai_busy: bool = false
var last_hover := BoardState.NONE
var promotion_target := BoardState.NONE
var persistence_enabled: bool = true
var music_director: MusicDirector
var music_volume: float = DEFAULT_MUSIC_VOLUME

func _ready() -> void:
	DisplayServer.window_set_title("Schachschlachtfeld")
	configure_display()
	get_window().size_changed.connect(configure_display)
	load_deck()
	music_director = MusicDirector.new()
	add_child(music_director)
	music_volume = load_music_volume()
	set_music_volume(music_volume, false)
	library = LibraryView.new()
	library.position.x = 40
	add_child(library)
	gallery = CardGallery.new()
	add_child(gallery)
	gallery.build(catalog)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui_root = Control.new()
	canvas.add_child(ui_root)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	configure_display()
	board_container = SubViewportContainer.new()
	board_container.stretch = true
	board_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(board_container)
	board_viewport = SubViewport.new()
	board_viewport.own_world_3d = true
	board_viewport.msaa_3d = Viewport.MSAA_2X
	board_container.add_child(board_viewport)
	board_view = BoardView.new()
	board_viewport.add_child(board_view)
	input_surface = BoardInput.new()
	ui_root.add_child(input_surface)
	input_surface.square_clicked.connect(on_board_click)
	input_surface.square_hovered.connect(on_board_hover)
	hud = WarRoomHUD.new()
	ui_root.add_child(hud)
	hud.board_rect_changed.connect(layout_board)
	hud.setup(catalog, gallery)
	hud.deck_confirmed.connect(confirm_deck)
	hud.deck_closed.connect(close_deck)
	hud.menu_requested.connect(open_main_menu)
	hud.restart_requested.connect(func(): start_match(deck))
	hud.promotion_chosen.connect(complete_promotion)
	hud.promotion_cancelled.connect(clear_selection)
	main_menu = MainMenu.new()
	ui_root.add_child(main_menu)
	main_menu.play_requested.connect(func(): start_match(deck))
	main_menu.deck_requested.connect(open_deck)
	main_menu.resume_requested.connect(resume_match)
	main_menu.abandon_requested.connect(abandon_match)
	main_menu.music_volume_changed.connect(set_music_volume)
	main_menu.quit_requested.connect(func(): get_tree().quit())
	open_main_menu()
	if "--battle-preview" in OS.get_cmdline_user_args():
		start_match(deck)
	for flag in ["--capture-menu", "--capture-deck", "--capture-battle"]:
		if flag in OS.get_cmdline_user_args():
			capture_smoke.call_deferred()
			break

func configure_display() -> void:
	var window := get_window()
	var density := maxf(1.0,DisplayServer.screen_get_dpi()/160.0) if OS.has_feature("mobile") else 1.0
	var logical := Vector2i(Vector2(window.size)/density)
	if window.content_scale_size != logical:
		window.content_scale_size = logical
	if ui_root == null:
		return
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		if safe.size.x > 0 and safe.size.y > 0:
			ui_root.offset_left = maxf(0,safe.position.x/density)
			ui_root.offset_top = maxf(0,safe.position.y/density)
			ui_root.offset_right = -maxf(0,(window.size.x-safe.end.x)/density)
			ui_root.offset_bottom = -maxf(0,(window.size.y-safe.end.y)/density)

func layout_board(rect: Rect2,phone: bool) -> void:
	board_container.position = rect.position-ui_root.global_position
	board_container.size = rect.size
	input_surface.position = board_container.position
	input_surface.size = rect.size
	board_view.fit_view(rect.size,phone)


func open_main_menu() -> void:
	music_director.play_cue("library")
	clear_selection()
	screen = Screen.MAIN
	hud.hide()
	input_surface.hide()
	board_container.hide()
	board_view.hide()
	library.show()
	library.set_process_mode(Node.PROCESS_MODE_INHERIT)
	library.camera.current = true
	main_menu.present(game != null and not game.finished, music_volume)

func show_battle() -> void:
	music_director.play_cue("battle")
	screen = Screen.BATTLE
	main_menu.hide()
	library.hide()
	library.set_process_mode(Node.PROCESS_MODE_DISABLED)
	board_container.show()
	board_view.show()
	board_view.camera.current = true
	input_surface.show()
	hud.show()
	hud.show_battle()

func resume_match() -> void:
	if game != null:
		show_battle()
		refresh()

func start_match(chosen: Array) -> void:
	match_generation += 1
	ai_busy = false
	deck = chosen.duplicate()
	save_deck()
	board_view.reset()
	game = GameManager.new(catalog, deck)
	game.changed.connect(refresh)
	game.event_occurred.connect(board_view.flash_event)
	clear_selection()
	show_battle()
	refresh()

func refresh() -> void:
	board_view.sync(game)
	hud.sync(game)
	if game.finished or game.turn != 0:
		clear_selection()
	else:
		update_targets()
	if screen == Screen.BATTLE and game.turn == 1 and not game.finished and not ai_busy:
		run_opponent()

func clear_selection() -> void:
	selected = BoardState.NONE
	promotion_target = BoardState.NONE
	last_hover = BoardState.NONE
	targets.clear()
	board_view.select(selected, targets)
	if hud != null:
		hud.promotion_layer.hide()
		hud.inspect(null)

func update_targets() -> void:
	targets.clear()
	if game != null and game.turn == 0 and not game.finished:
		targets = game.legal_targets(selected)
	board_view.select(selected, targets)

func on_board_click(pos: Vector2) -> void:
	if game == null or screen != Screen.BATTLE or game.turn != 0 or game.finished or hud.promotion_layer.visible:
		return
	var cell := board_view.pick(pos)
	if not BoardState.inside(cell):
		clear_selection()
		return
	if cell in targets and BoardState.inside(selected):
		if MovementRules.needs_promotion(game.board.at(selected), cell):
			promotion_target = cell
			hud.show_promotion()
		elif not game.move_unit(selected, cell):
			hud.hint_label.text = game.last_error
		return
	var unit := game.board.at(cell)
	clear_selection()
	if unit != null:
		hud.inspect(unit)
		if unit.team == 0:
			selected = cell
			update_targets()

func complete_promotion(id: String) -> void:
	if game == null or screen != Screen.BATTLE or not hud.promotion_layer.visible or game.turn != 0:
		return
	if not game.move_unit(selected, promotion_target, id):
		hud.hint_label.text = game.last_error

func on_board_hover(pos: Vector2) -> void:
	if game == null or screen != Screen.BATTLE or hud.promotion_layer.visible:
		return
	var cell := board_view.pick(pos)
	if cell == last_hover:
		return
	last_hover = cell
	board_view.select(selected, targets, cell if cell in targets else BoardState.NONE)

func run_opponent() -> void:
	ai_busy = true
	var generation := match_generation
	await get_tree().create_timer(OPPONENT_INTERVAL).timeout
	if generation != match_generation:
		return
	ai_busy = false
	# A pause cancels this request; resume schedules one fresh request.
	if screen == Screen.BATTLE and game.turn == 1 and not game.finished:
		TacticalAI.act(game)

func open_deck() -> void:
	if screen != Screen.MAIN or (game != null and not game.finished):
		return
	clear_selection()
	screen = Screen.DECK
	main_menu.hide()
	input_surface.hide()
	hud.show()
	hud.show_deck(deck)

func confirm_deck(chosen: Array) -> void:
	if screen != Screen.DECK or (game != null and not game.finished) or not catalog.valid_deck(chosen):
		return
	deck = chosen.duplicate()
	save_deck()
	close_deck()

func abandon_match() -> void:
	if game != null and not game.finished:
		show_battle()
		game.resign(0)

func close_deck() -> void:
	open_main_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if screen == Screen.DECK:
			close_deck()
		elif screen == Screen.MAIN:
			if main_menu.settings_panel.visible:
				main_menu.close_settings()
			elif game != null and not game.finished:
				resume_match()
		elif BoardState.inside(selected):
			clear_selection()
		else:
			open_main_menu()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and screen == Screen.BATTLE:
		clear_selection()

func load_deck() -> void:
	if not persistence_enabled:
		return
	var path := "user://deck.json"
	if not FileAccess.file_exists(path):
		# Preserve saved unit choices after changing the application's working title.
		path = OS.get_user_data_dir().get_base_dir().path_join("Chess Royale — Ash & Iron/deck.json")
	if FileAccess.file_exists(path):
		var value = JSON.parse_string(FileAccess.get_file_as_string(path))
		# Keep valid unit choices from older decks; old spell slots are retired.
		if value is Array and value.size() >= 16 and catalog.valid_deck(value.slice(0, 16)):
			deck = value.slice(0, 16)

func load_music_volume() -> float:
	if not persistence_enabled:
		return DEFAULT_MUSIC_VOLUME
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		return clampf(float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	return DEFAULT_MUSIC_VOLUME

func set_music_volume(value: float, save: bool = true) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	var bus_index := AudioServer.get_bus_index(MusicDirector.MUSIC_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_volume_linear(bus_index, music_volume)
	if save and persistence_enabled:
		var config := ConfigFile.new()
		config.set_value("audio", "music_volume", music_volume)
		config.save(SETTINGS_PATH)

func save_deck() -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open("user://deck.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(deck))

func capture_smoke() -> void:
	await get_tree().create_timer(1.0).timeout
	var filename := "menu"
	if "--capture-battle" in OS.get_cmdline_user_args():
		filename = "battle"
		start_match(deck)
		selected = Vector2i(7, 1)
		update_targets()
		hud.inspect(game.board.at(selected))
	elif "--capture-deck" in OS.get_cmdline_user_args():
		filename = "deck"
		open_deck()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var path := "user://%s.png" % filename
	get_viewport().get_texture().get_image().save_png(path)
	print("Screenshot: ", ProjectSettings.globalize_path(path))
	get_tree().quit()
