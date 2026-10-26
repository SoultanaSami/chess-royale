class_name WarRoomHUD
extends Control
## Mobile chess HUD and pre-match variant selection. Spells are read-only briefs.
signal deck_confirmed(deck: Array)
signal deck_closed
signal menu_requested
signal restart_requested
signal promotion_chosen(id: String)
signal promotion_cancelled
signal board_rect_changed(rect: Rect2, compact: bool)

var catalog: Catalog
var gallery: CardGallery
var game: GameManager
var battle_layer: Control
var deck_layer: Control
var turn_label: Label
var position_label: Label
var detail_title: Label
var detail_body: Label
var hint_label: Label
var last_move_label: Label
var deck_count: Label
var confirm_button: Button
var close_button: Button
var outcome: PanelContainer
var outcome_title: Label
var outcome_reason: Label
var promotion_layer: Control
var promotion_panel: PanelContainer
var promotion_buttons: Dictionary = {}
var chosen_deck: Array = []
var board_rect: Rect2
var compact: bool = false
var details: Panel
var footer: Panel
var header: Panel
var menu_button: Button
var selected_unit: UnitState
var filter_type: String = "ROOK"
var slot_selectors: Array[OptionButton] = []
var slot_rows: Array[PanelContainer] = []
var spell_rows: Array[PanelContainer] = []
var slot_list: VBoxContainer
var slot_scroll: ScrollContainer
var tabs: HBoxContainer
var tabs_scroll: ScrollContainer
var deck_title: Label
var deck_hint: Label
const CLASS_NAMES = {"PAWN":"Bauern", "KNIGHT":"Springer", "BISHOP":"Läufer", "ROOK":"Türme", "QUEEN":"Dame", "KING":"König", "SPELL":"Zauber"}

func setup(data: Catalog, art: CardGallery) -> void:
	catalog = data
	gallery = art
	theme = VisualTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_battle()
	build_deck()
	resized.connect(layout)
	layout()

func full_layer() -> Control:
	var layer := Control.new()
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer

func button(parent: Node, text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 48
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func panel(parent: Node) -> Panel:
	var value := Panel.new()
	value.add_theme_stylebox_override("panel",VisualTheme.panel(Color("14191cf2"),Color("594a36")))
	parent.add_child(value)
	return value

func label_at(parent: Node,text: String,pos: Vector2,font_size: int = 16,title: bool = false) -> Label:
	var value := VisualTheme.label(parent,text,font_size,VisualTheme.CREAM,title)
	value.position = pos
	return value

func build_battle() -> void:
	battle_layer = full_layer()
	header = panel(battle_layer)
	turn_label = label_at(header,"Dein Zug",Vector2(16,10),20,true)
	position_label = label_at(header,"",Vector2(16,39),13)
	menu_button = button(header,"MENÜ",func(): menu_requested.emit())
	footer = panel(battle_layer)
	last_move_label = label_at(footer,"",Vector2(12,10),14)
	last_move_label.clip_text = true
	hint_label = label_at(battle_layer,"Figur antippen",Vector2.ZERO,13)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details = panel(battle_layer)
	detail_title = label_at(details,"",Vector2(12,10),16,true)
	detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body = label_at(details,"",Vector2(12,44),13)
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.add_theme_constant_override("line_spacing",2)
	details.hide()
	outcome = PanelContainer.new()
	battle_layer.add_child(outcome)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	outcome.add_child(box)
	outcome_title = VisualTheme.label(box,"SIEG",30,VisualTheme.GOLD,true)
	outcome_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_reason = VisualTheme.label(box,"",17,VisualTheme.CREAM)
	outcome_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(box,"HAUPTMENÜ",func(): menu_requested.emit())
	var rematch := button(box,"NEUES SPIEL",func(): restart_requested.emit())
	rematch.name = "Rematch"
	outcome.hide()
	promotion_layer = Control.new()
	battle_layer.add_child(promotion_layer)
	promotion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	promotion_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.025,0.03,0.8)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	promotion_layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	promotion_panel = PanelContainer.new()
	promotion_layer.add_child(promotion_panel)
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation",12)
	promotion_panel.add_child(choices)
	var title := VisualTheme.label(choices,"UMWANDLUNG",22,VisualTheme.GOLD,true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	choices.add_child(grid)
	for id in MovementRules.PROMOTIONS:
		var choice := button(grid,{"queen":"Dame","ram":"Turm","assassin":"Läufer","cavalry":"Springer"}[id],func(): promotion_chosen.emit(id))
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		promotion_buttons[id] = choice
	button(choices,"ABBRECHEN",func(): promotion_cancelled.emit())
	promotion_layer.hide()

func build_deck() -> void:
	deck_layer = full_layer()
	var background := ColorRect.new()
	background.color = Color("111719")
	deck_layer.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deck_title = label_at(deck_layer,"DECKS",Vector2(16,16),24,true)
	deck_count = label_at(deck_layer,"8×8 · 16 Figuren pro Seite · Testaufstellung",Vector2(16,55),12)
	tabs_scroll = ScrollContainer.new()
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_layer.add_child(tabs_scroll)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation",6)
	tabs_scroll.add_child(tabs)
	# Zauber is visible without horizontal scrolling on the smallest phone.
	for kind in ["ROOK","SPELL","KNIGHT","BISHOP","QUEEN","KING","PAWN"]:
		var tab := button(tabs,CLASS_NAMES[kind],func(): set_filter(kind))
		tab.name = kind
		tab.custom_minimum_size.x = 88
	deck_hint = label_at(deck_layer,"",Vector2.ZERO,13)
	deck_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_scroll = ScrollContainer.new()
	slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_layer.add_child(slot_scroll)
	slot_list = VBoxContainer.new()
	slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_list.add_theme_constant_override("separation",12)
	slot_scroll.add_child(slot_list)
	for index in range(16):
		var row := PanelContainer.new()
		row.custom_minimum_size.y = 108
		slot_list.add_child(row)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation",12)
		row.add_child(box)
		var art := TextureRect.new()
		art.name = "Portrait"
		art.custom_minimum_size = Vector2(64,64)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(art)
		var info := VBoxContainer.new()
		info.name = "Info"
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation",8)
		box.add_child(info)
		var cell := Vector2i(7 if index < 8 else 6,index%8)
		VisualTheme.label(info,"%s · %s" % [GameManager.notation(cell),CLASS_NAMES[Catalog.SLOT_TYPES[index]]],13,VisualTheme.GOLD)
		var selector := OptionButton.new()
		selector.custom_minimum_size.y = 48
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.fit_to_longest_item = false
		selector.add_theme_font_size_override("font_size",13)
		for id in catalog.variants_for(Catalog.SLOT_TYPES[index]):
			selector.add_item(catalog.get_piece(id).display_name)
			selector.set_item_metadata(selector.item_count-1,id)
		selector.item_selected.connect(func(option): change_variant(index,selector.get_item_metadata(option)))
		info.add_child(selector)
		var description := VisualTheme.label(info,"",12,VisualTheme.MUTED)
		description.name = "Description"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_selectors.append(selector)
		slot_rows.append(row)
	for id in ["bind","protect"]:
		var data := catalog.get_piece(id)
		var row := PanelContainer.new()
		row.set_meta("spell_id",id)
		slot_list.add_child(row)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation",10)
		row.add_child(content)
		VisualTheme.label(content,data.display_name,21,VisualTheme.GOLD,true)
		var description := VisualTheme.label(content,data.description,14,VisualTheme.CREAM)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var note := VisualTheme.label(content,"Noch offen: " + data.open_rules,12,VisualTheme.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spell_rows.append(row)
	close_button = button(deck_layer,"ZURÜCK",func(): deck_closed.emit())
	confirm_button = button(deck_layer,"SPEICHERN",confirm_deck)

func layout() -> void:
	if battle_layer == null:
		return
	var w := size.x
	var h := size.y
	compact = w < 700 or h < 550
	var landscape_phone := h < 550 and w > h
	if landscape_phone:
		var bw := minf(h*1.06,w*0.59)
		board_rect = Rect2(6,6,bw,h-12)
		var x := bw+18
		var right_width := w-x-10
		header.position = Vector2(x,6)
		header.size = Vector2(right_width,76)
		footer.position = Vector2(x,h-54)
		footer.size = Vector2(right_width,48)
		details.position = Vector2(x,92)
		details.size = Vector2(right_width,maxf(100,h-206))
		hint_label.position = Vector2(x,h-106)
		hint_label.size = Vector2(right_width,48)
	elif w < 700:
		header.position = Vector2(8,8)
		header.size = Vector2(w-16,68)
		var detail_height := 134.0 if h < 740 else 150.0
		var bh := minf(w*1.12,h-80-56-detail_height-64)
		board_rect = Rect2(0,80,w,maxf(180,bh))
		footer.position = Vector2(8,h-56)
		footer.size = Vector2(w-16,48)
		details.position = Vector2(8,board_rect.end.y+10)
		details.size = Vector2(w-16,detail_height)
		hint_label.position = Vector2(12,h-100)
		hint_label.size = Vector2(w-24,40)
	else:
		header.position = Vector2(20,12)
		header.size = Vector2(w-40,72)
		var bh := h-180
		var bw := minf(w-320,bh*1.12)
		board_rect = Rect2(maxf(10,(w-300-bw)/2),88,bw,bh)
		footer.position = Vector2(20,h-64)
		footer.size = Vector2(w-40,48)
		details.position = Vector2(w-290,110)
		details.size = Vector2(270,260)
		hint_label.position = Vector2(board_rect.position.x,h-92)
		hint_label.size = Vector2(bw,24)
	menu_button.position = Vector2(header.size.x-96,12)
	menu_button.size = Vector2(84,48)
	turn_label.size.x = header.size.x-120
	turn_label.clip_text = true
	position_label.size.x = header.size.x-30
	position_label.clip_text = true
	last_move_label.size = Vector2(footer.size.x-24,28)
	detail_title.size = Vector2(details.size.x-24,30)
	detail_body.size = Vector2(details.size.x-24,details.size.y-54)
	detail_body.max_lines_visible = 5 if compact else 10
	outcome.position = Vector2(maxf(12,w/2-210),h/2-132)
	outcome.size = Vector2(minf(420,w-24),264)
	promotion_panel.size = Vector2(minf(360,w-24),244)
	promotion_panel.position = (size-promotion_panel.size)/2
	board_rect_changed.emit(Rect2(global_position+board_rect.position,board_rect.size),compact)
	if deck_layer != null:
		var max_width := minf(w-24,820)
		var x := (w-max_width)/2
		deck_title.position = Vector2(x,16)
		deck_count.position = Vector2(x,55)
		tabs_scroll.position = Vector2(x,88)
		tabs_scroll.size = Vector2(max_width,62)
		deck_hint.position = Vector2(x,158)
		deck_hint.size = Vector2(max_width,48)
		slot_scroll.position = Vector2(x,214)
		slot_scroll.size = Vector2(max_width,maxf(60,h-290))
		close_button.position = Vector2(x,h-64)
		close_button.size = Vector2(130,48)
		confirm_button.position = Vector2(x+max_width-148,h-64)
		confirm_button.size = Vector2(148,48)

func show_deck(deck: Array) -> void:
	chosen_deck = deck.duplicate()
	battle_layer.hide()
	deck_layer.show()
	for index in range(16):
		var selector := slot_selectors[index]
		for option in range(selector.item_count):
			if selector.get_item_metadata(option) == chosen_deck[index]:
				selector.select(option)
		update_portrait(index)
	set_filter("ROOK")
	layout()

func update_portrait(index: int) -> void:
	var row := slot_rows[index]
	var texture: TextureRect = row.get_child(0).get_node("Portrait")
	texture.texture = gallery.textures.get(chosen_deck[index])
	row.get_child(0).get_node("Info/Description").text = catalog.get_piece(chosen_deck[index]).description

func set_filter(kind: String) -> void:
	filter_type = kind
	for index in range(16):
		slot_rows[index].visible = Catalog.SLOT_TYPES[index] == kind
	for row in spell_rows:
		row.visible = kind == "SPELL"
	for tab in tabs.get_children():
		tab.modulate = Color.WHITE if tab.name == kind else Color("aaa69c")
	deck_hint.text = "Vorschau · Noch nicht im Match einsetzbar.\nDie Einsatzregeln bleiben offen." if kind == "SPELL" else "Aktuell gelten klassische Schachzüge.\nSpezialfähigkeiten und weitere Deckregeln sind offen."
	# Spell entries do not create loadout slots or usage limits.
	confirm_button.visible = kind != "SPELL"
	slot_scroll.scroll_vertical = 0

func change_variant(index: int,id: String) -> void:
	if index < 0 or index >= 16 or not id in catalog.variants_for(Catalog.SLOT_TYPES[index]):
		return
	chosen_deck[index] = id
	update_portrait(index)

func confirm_deck() -> void:
	if catalog.valid_deck(chosen_deck):
		deck_confirmed.emit(chosen_deck.duplicate())

func show_battle() -> void:
	deck_layer.hide()
	battle_layer.show()
	layout()

func show_promotion() -> void:
	promotion_layer.show()
	layout()
	promotion_buttons["queen"].grab_focus()

func sync(match_state: GameManager) -> void:
	game = match_state
	var checked := game.in_check(game.turn)
	turn_label.text = "Dein Zug" if game.turn == 0 else "Gegnerzug"
	turn_label.add_theme_color_override("font_color",Color("ffb4a0") if checked else VisualTheme.CREAM)
	position_label.text = "Zug %d · %s" % [game.round_number,"Weiß (du)" if game.turn == 0 else "Schwarz"]
	if checked:
		position_label.text += " · SCHACH"
	last_move_label.text = "Letzter Zug: " + game.history.back() if not game.history.is_empty() else "Weiß beginnt"
	outcome.visible = game.finished
	outcome_title.text = "REMIS" if game.winner < 0 else ("SIEG" if game.winner == 0 else "NIEDERLAGE")
	outcome_reason.text = game.result_reason
	if game.finished:
		turn_label.text = "Spiel beendet"
		hint_label.text = game.result_reason
	elif checked:
		hint_label.text = "Dein König steht im Schach." if game.turn == 0 else "Der gegnerische König steht im Schach."
	else:
		hint_label.text = "Figur antippen, dann Zielfeld wählen" if game.turn == 0 else "Gegner am Zug…"
	layout()

func inspect(unit: UnitState) -> void:
	selected_unit = unit
	details.visible = unit != null
	if unit == null:
		return
	var data := catalog.get_piece(unit.variant_id)
	detail_title.text = data.display_name
	detail_body.text = data.description
	layout()
