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
var footer: PanelContainer
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
	var top := PanelContainer.new()
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 22)
	top.add_child(header)
	status = VisualTheme.label(header, "", 17, VisualTheme.CREAM)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_status = VisualTheme.label(header, "", 15, Color("e0a092"))
	clock_label = VisualTheme.label(header, "", 16, VisualTheme.GOLD)
	button(header, "MENÜ · ESC", func(): pause_requested.emit())
	footer = PanelContainer.new()
	add_child(footer)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	footer.add_child(content)
	selected_info = VisualTheme.label(content, "", 14, VisualTheme.CREAM)
	var hand := HBoxContainer.new()
	hand.add_theme_constant_override("separation", 8)
	content.add_child(hand)
	for slot in range(5):
		var card := ReserveCard.new()
		card.slot = slot
		card.toggle_mode = true
		card.custom_minimum_size = Vector2(150, 126)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(func(): slot_selected.emit(slot))
		card.drag_started.connect(func(index): slot_selected.emit(index))
		hand.add_child(card)
		cards.append(card)
		var rows := VBoxContainer.new()
		rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(rows)
		rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rows.offset_left = 8
		rows.offset_right = -8
		rows.offset_top = 6
		rows.offset_bottom = -6
		var name_label := VisualTheme.label(rows, "[%d] %s" % [slot + 1, ROLES[slot]], 12, VisualTheme.GOLD, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var picture := TextureRect.new()
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.custom_minimum_size = Vector2(0, 58)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rows.add_child(picture)
		portraits.append(picture)
		var title := VisualTheme.label(rows, "", 11)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_names.append(title)
		var cost := VisualTheme.label(rows, "", 13, VisualTheme.GOLD)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_costs.append(cost)
	var commands := VBoxContainer.new()
	commands.custom_minimum_size.x = 154
	hand.add_child(commands)
	end_button = button(commands, "ZUG BEENDEN\nLEERTASTE", func(): end_requested.emit())
	end_button.custom_minimum_size.y = 72
	shoot_button = button(commands, "FERNANGRIFF · R", func(): shoot_requested.emit())
	shoot_button.toggle_mode = true
	message = VisualTheme.label(content, "", 13, VisualTheme.GOLD)
	var help := VisualTheme.label(content, "1–5 / Karte ziehen: Rekrutieren  ·  Shift-Klick / Auswahlrahmen: Bauernreihe  ·  G: Formation vor  ·  WASD / Rand: Kamera  ·  Mausrad / MMT: Zoom / Drehen  ·  F: Übersicht", 11, VisualTheme.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var rules := VisualTheme.label(box, "Jeder Zug: 3 KP. Bewegen, Rekrutieren, Schießen oder eine Bauernreihe vorrücken kostet 1 KP.\nRekrutierung kostet zusätzlich Gold und ist neben deiner Burg möglich. Neu rekrutierte Figuren dürfen sofort handeln.\nBesetze Goldminen am Zugende: Naturminen liefern +2 Gold, die drei umkämpften Minen +3. Deine Burg liefert +2.\nBelagerte Burg: Löse die Bedrohung oder verliere am Zugende einen Schild. Drei verlorene Schilde oder Matt bedeuten Niederlage.\nBauern ziehen bis 2, Läufer 3, Türme und Damen bis 4 Felder. Wald kostet 2 Bewegungspunkte; Türme meiden ihn.\nKlippengrenzen brauchen Rampen. Läufer auf Hochland schießen diagonal 4 Felder; Angriffe bergauf brauchen einen eigenen Späher oben.\nBauern werden am gegenüberliegenden Kartenrand zur Dame. Du kämpfst gegen einen lokalen Gegner.", 14)
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
	if footer == null:
		return
	var width := minf(1120, size.x - 32)
	footer.size = Vector2(width, 222)
	footer.position = Vector2((size.x - width) * .5, size.y - footer.size.y - 12)

func sync(game: TacticalMatch, selected_slot: int, selected: UnitState, shooting: bool, ready: bool) -> void:
	update_clock(game)
	status.text = "RUNDE %d · %s\nGold %d (+%d)   ·   KP %d/%d   ·   Goldminen %d" % [game.round_number, "DEIN ZUG" if game.turn == 0 else "GEGNER AM ZUG", game.gold[0], game.income(0), game.cp if game.turn == 0 else 0, game.config.max_cp, game.mines_owned(0)]
	var ours := game.board.tile_at(TacticalCommands.castle(game.board, 0)).garrison_shields
	var theirs := game.board.tile_at(TacticalCommands.castle(game.board, 1)).garrison_shields
	enemy_status.text = "Deine Burg %d/3%s\nGegnerburg %d/3%s" % [ours, " · BELAGERT!" if game.siege[0] else "", theirs, " · BELAGERT!" if game.siege[1] else ""]
	for slot in range(5):
		var data := game.catalog.get_unit(game.reserves[0][slot])
		cards[slot].disabled = not ready or game.deploy_targets(slot, 0).is_empty()
		cards[slot].set_pressed_no_signal(slot == selected_slot)
		cards[slot].tooltip_text = "%s\n%d Gold + 1 KP · neben deiner Burg rekrutieren" % [data.unit_name, data.resource_cost]
		card_names[slot].text = data.unit_name
		card_costs[slot].text = "%d GOLD · 1 KP" % data.resource_cost
		portraits[slot].texture = textures.get(str(data.id))
	end_button.disabled = not ready or game.finished or game.turn != 0
	shoot_button.disabled = not ready or selected == null or selected.team != 0 or selected.definition.ranged_attack_range == 0 or not game.can_act(0)
	shoot_button.set_pressed_no_signal(shooting)
	if selected != null:
		var reach := selected.definition.attack_range + (1 if selected.chess_type == "BISHOP" and game.board.tile_at(selected.cell).elevation == 2 else 0)
		selected_info.text = "%s · %s · Bewegung %d · Angriff %d%s" % [selected.definition.unit_name, "Deine Einheit" if selected.team == 0 else "Gegner", selected.definition.max_move_range, reach, " · 2 L-Sprünge" if selected.definition.knight_jumps == 2 else " · Fernkampf" if selected.definition.ranged else ""]
	else:
		selected_info.text = "Reservekarte wählen oder eigene Figur anklicken."

	message.text = game.last_event if game.cp > 0 else "Keine KP mehr — Zug mit Leertaste beenden."
	if game.siege[0]:
		message.text = "DEINE BURG WIRD BELAGERT — Angreifer schlagen oder Angriffslinie blockieren!"
	if game.finished:
		outcome_title.text = "SIEG" if game.winner == 0 else "NIEDERLAGE"
		outcome_detail.text = game.result_reason + " · Runde %d" % game.round_number
		outcome_layer.show()

func update_clock(game: TacticalMatch) -> void:
	clock_label.text = "%ds" % ceili(game.remaining_time) if game.config.turn_time_limit > 0 else ""
