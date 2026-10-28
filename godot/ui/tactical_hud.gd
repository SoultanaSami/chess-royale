class_name TacticalHUD
extends Control
signal slot_selected(slot: int)
signal end_requested
signal pause_requested
signal resume_requested
signal resign_requested
signal restart_requested
signal menu_requested
signal start_requested(deck: Array)
signal shoot_requested
signal music_changed(value: float)
const ROLES := ["BAUER", "SPRINGER", "LÄUFER", "TURM", "DAME"]
var cards: Array[ReserveCard] = []
var card_names: Array[Label] = []
var card_costs: Array[Label] = []
var portraits: Array[TextureRect] = []
var selectors: Array[OptionButton] = []
var chosen: Array = TacticalCatalog.DEFAULT_RESERVE.duplicate()
var textures: Dictionary
var catalog: TacticalCatalog
var status: Label
var enemy_status: Label
var selected_info: Label
var message: Label
var end_button: Button
var shoot_button: Button
var footer: Control
var left_crest: TacticalCrest
var right_crest: TacticalCrest
var command_column: VBoxContainer
var help_label: Label
var deck_layer: ColorRect
var pause_layer: ColorRect
var outcome_layer: ColorRect
var outcome_title: Label
var outcome_detail: Label
var volume: HSlider
var clock_label: Label

func build(data: TacticalCatalog, pictures: Dictionary, deck: Array) -> void:
	catalog = data
	textures = pictures
	chosen = deck.duplicate()
	theme = VisualTheme.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_crest = TacticalCrest.new()
	left_crest.size = Vector2(340,122)
	add_child(left_crest)
	status = left_crest.caption
	right_crest = TacticalCrest.new()
	right_crest.economy = false
	right_crest.size = Vector2(318,112)
	add_child(right_crest)
	enemy_status = right_crest.caption
	enemy_status.add_theme_font_size_override("font_size",12)
	enemy_status.add_theme_constant_override("line_spacing",28)
	enemy_status.size = Vector2(194,90)
	clock_label = VisualTheme.label(self,"",16,VisualTheme.GOLD)
	var menu := button(self,"MENÜ · ESC",func(): pause_requested.emit())
	menu.name = "PauseButton"
	menu.custom_minimum_size = Vector2(134,36)
	footer = Control.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	selected_info = VisualTheme.label(self,"",13,VisualTheme.CREAM)
	selected_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_info.add_theme_color_override("font_shadow_color",Color.BLACK)
	selected_info.add_theme_constant_override("shadow_offset_y",2)
	message = VisualTheme.label(self,"",14,VisualTheme.GOLD)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_shadow_color",Color.BLACK)
	message.add_theme_constant_override("shadow_offset_y",2)
	for slot in range(5):
		var card := ReserveCard.new()
		card.slot = slot
		card.size = Vector2(154,210)
		card.pressed.connect(func(): slot_selected.emit(slot))
		card.drag_started.connect(func(index): slot_selected.emit(index))
		footer.add_child(card)
		cards.append(card)
	command_column = VBoxContainer.new()
	command_column.add_theme_constant_override("separation",10)
	footer.add_child(command_column)
	end_button = button(command_column,"ZUG BEENDEN\nLEERTASTE",func(): end_requested.emit())
	end_button.custom_minimum_size = Vector2(142,70)
	shoot_button = button(command_column,"FERNANGRIFF · R",func(): shoot_requested.emit())
	shoot_button.toggle_mode = true
	help_label = VisualTheme.label(self,"1–5 / Ziehen: Rekrutieren  ·  Shift / Rahmen: Formation  ·  G: Vorrücken  ·  WASD / Rand: Kamera  ·  Mausrad / MMT: Zoom / Drehen  ·  F: Übersicht",11,VisualTheme.MUTED)
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_deck()
	build_pause()
	var outcome := overlay()
	outcome_layer = outcome.layer
	outcome_title = VisualTheme.label(outcome.box, "", 30, VisualTheme.GOLD, true)
	outcome_detail = VisualTheme.label(outcome.box, "", 17)
	button(outcome.box, "NEUE SCHLACHT", func(): restart_requested.emit())
	button(outcome.box, "HAUPTMENÜ", func(): menu_requested.emit())
	outcome_layer.hide()
	resized.connect(layout)
	layout()

func button(parent: Node, text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 44
	result.pressed.connect(action)
	parent.add_child(result)
	return result

func overlay() -> Dictionary:
	var layer := ColorRect.new()
	layer.color = Color(0.025, .035, .04, .94)
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 640
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	return {"layer": layer, "box": box}

func build_deck() -> void:
	var modal := overlay()
	deck_layer = modal.layer
	var box: VBoxContainer = modal.box
	VisualTheme.label(box, "DIE ASCHENKLIPPEN", 30, VisualTheme.GOLD, true)
	VisualTheme.label(box, "24 × 32 Felder · Wähle deine fünf Reserve-Einheiten", 17)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for role in range(5):
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 168
		row.add_child(column)
		VisualTheme.label(column, ROLES[role], 15, VisualTheme.GOLD, true)
		var picture := TextureRect.new()
		picture.custom_minimum_size = Vector2(160, 120)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture = textures.get(chosen[role])
		column.add_child(picture)
		var options := OptionButton.new()
		options.custom_minimum_size.y = 44
		column.add_child(options)
		selectors.append(options)
		for unit in catalog.variants_for(role):
			options.add_item("%s · %d Gold" % [unit.unit_name, unit.resource_cost])
			options.set_item_metadata(options.item_count - 1, unit.id)
			if str(unit.id) == str(chosen[role]):
				options.select(options.item_count - 1)
		options.item_selected.connect(func(index):
			chosen[role] = str(options.get_item_metadata(index))
			picture.texture = textures.get(chosen[role])
		)
	var rules := VisualTheme.label(box, "Jeder Zug: 3 KP. Bewegen, Rekrutieren, Schießen oder eine Bauernreihe vorrücken kostet 1 KP.\nRekrutierung kostet zusätzlich Gold und ist neben deiner Burg möglich. Neu rekrutierte Figuren dürfen sofort handeln.\nBesetze den freien Eroberungsring einer Goldmine am Zugende ohne Gegner im Ring: Naturminen liefern +2 Gold, die drei umkämpften Minen +3. Deine Burg liefert +2.\nBelagerte Burg: Löse die Bedrohung oder verliere am Zugende einen Schild. Drei verlorene Schilde oder Matt bedeuten Niederlage.\nBauern ziehen bis 2, Läufer 3, Türme und Damen bis 4 Felder. Wald kostet 2 Bewegungspunkte; Türme meiden ihn.\nKlippengrenzen brauchen Rampen. Läufer auf Hochland schießen diagonal 4 Felder; Angriffe bergauf brauchen einen eigenen Späher oben.\nBauern werden am gegenüberliegenden Kartenrand zur Dame. Du kämpfst gegen einen lokalen Gegner.", 14)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(box, "SCHLACHT BEGINNEN", func(): start_requested.emit(chosen.duplicate()))
	button(box, "ZURÜCK", func(): menu_requested.emit())

func build_pause() -> void:
	var modal := overlay()
	pause_layer = modal.layer
	var box: VBoxContainer = modal.box
	VisualTheme.label(box, "PAUSE", 28, VisualTheme.GOLD, true)
	VisualTheme.label(box, "Goldminen: Besitzwechsel am Zugende, Einkommen beim nächsten Zugbeginn.\nBelagerung: Angreifer schlagen oder ihre Angriffslinie blockieren.\nFormation: zwei oder mehr direkt nebeneinander stehende Bauern auswählen.", 14)
	VisualTheme.label(box, "MUSIKLAUTSTÄRKE", 14)
	volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.custom_minimum_size.y = 36
	volume.value_changed.connect(func(value): music_changed.emit(value / 100.0))
	box.add_child(volume)
	button(box, "FORTSETZEN", func(): resume_requested.emit())
	button(box, "AUFGEBEN", func(): resign_requested.emit())
	pause_layer.hide()

func layout() -> void:
	if footer == null: return
	left_crest.position = Vector2(18,16)
	right_crest.position = Vector2(size.x-right_crest.size.x-18,16)
	get_node("PauseButton").position = Vector2(size.x-158,138)
	clock_label.position = Vector2(size.x*.5-20,22)
	var width := minf(1150,size.x-32)
	footer.size = Vector2(width,246)
	footer.position = Vector2((size.x-width)*.5,size.y-260)
	var card_width := clampf((width-245)/5,118,154)
	var hand_width := card_width*5+12*4
	for i in range(5):
		cards[i].size = Vector2(card_width,210)
		cards[i].home = Vector2((width-hand_width)*.5+i*(card_width+12),25)
	command_column.position = Vector2((width+hand_width)*.5+16,80)
	selected_info.position = Vector2(16,footer.position.y-42)
	selected_info.size = Vector2(size.x-32,22)
	message.position = Vector2(16,footer.position.y-69)
	message.size = Vector2(size.x-32,22)
	help_label.position = Vector2(12,size.y-24)
	help_label.size.x = size.x-24

func sync(game: TacticalMatch, selected_slot: int, selected: UnitState, shooting: bool, ready: bool) -> void:
	update_clock(game)
	status.text = "RUNDE %d · %s" % [game.round_number,"DEIN ZUG" if game.turn==0 else "GEGNER AM ZUG"]
	left_crest.update_economy(game.gold[0],game.income(0),game.mines_owned(0),game.cp if game.turn==0 else 0,game.config.max_cp)
	var ours := game.board.tile_at(TacticalCommands.castle(game.board,0)).garrison_shields
	var theirs := game.board.tile_at(TacticalCommands.castle(game.board,1)).garrison_shields
	right_crest.shields = [ours,theirs]
	enemy_status.text = "DEINE BURG%s\nGEGNERBURG%s" % [" · BELAGERT" if game.siege[0] else ""," · BELAGERT" if game.siege[1] else ""]
	for slot in range(5):
		var data := game.catalog.get_unit(game.reserves[0][slot])
		if cards[slot].data != data: cards[slot].configure(data,textures.get(str(data.id)))
		cards[slot].set_state(ready and not game.deploy_targets(slot,0).is_empty(),slot==selected_slot)
	end_button.disabled = not ready or game.finished or game.turn != 0
	shoot_button.disabled = not ready or selected == null or selected.team != 0 or selected.definition.ranged_attack_range == 0 or not game.can_act(0)
	shoot_button.set_pressed_no_signal(shooting)
	if selected != null:
		var reach := selected.definition.attack_range + (1 if selected.chess_type == "BISHOP" and game.board.tile_at(selected.cell).elevation == 2 else 0)
		selected_info.text = "%s · %s · Bewegung %d · Angriff %d%s" % [selected.definition.unit_name, "Deine Einheit" if selected.team == 0 else "Gegner", selected.definition.max_move_range, reach, " · 2 L-Sprünge" if selected.definition.knight_jumps == 2 else " · Fernkampf" if selected.definition.ranged else ""]
	else:
		selected_info.text = "Reservekarte wählen oder eigene Figur anklicken."

	message.text = "" if game.cp > 0 else "Keine KP mehr — Zug mit Leertaste beenden."
	if game.siege[0]:
		message.text = "DEINE BURG WIRD BELAGERT — Angreifer schlagen oder Angriffslinie blockieren!"
	if game.finished:
		outcome_title.text = "SIEG" if game.winner == 0 else "NIEDERLAGE"
		outcome_detail.text = game.result_reason + " · Runde %d" % game.round_number
		outcome_layer.show()

func update_clock(game: TacticalMatch) -> void:
	clock_label.text = "%ds" % ceili(game.remaining_time) if game.config.turn_time_limit > 0 else ""
