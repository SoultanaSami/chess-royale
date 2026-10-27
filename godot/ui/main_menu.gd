class_name MainMenu
extends Control
signal play_requested
signal deck_requested
signal resume_requested
signal quit_requested
signal abandon_requested
signal settings_requested
signal music_volume_changed(value: float)
signal settings_closed
var abandon_button: Button
var resume_button: Button
var play_button: Button
var deck_button: Button
var title: Label
var buttons: VBoxContainer
var settings_panel: PanelContainer
var music_slider: HSlider
var music_value: Label

func _ready() -> void:
	theme = VisualTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.018,0.021,0.028,0.94))
	gradient.set_color(1,Color(0.018,0.021,0.028,0.0))
	gradient.add_point(0.36,Color(0.018,0.021,0.028,0.8))
	gradient.add_point(0.7,Color(0.018,0.021,0.028,0.05))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0,0)
	texture.fill_to = Vector2(1,0)
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title = VisualTheme.label(self,"SCHACH\nSCHLACHTFELD",44,Color("ead8b3"),true)
	title.add_theme_constant_override("line_spacing",0)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation",12)
	add_child(buttons)
	play_button = menu_button("SPIELEN",func(): play_requested.emit())
	deck_button = menu_button("DECKS",func(): deck_requested.emit())
	resume_button = menu_button("FORTSETZEN",func(): resume_requested.emit())
	abandon_button = menu_button("PARTIE AUFGEBEN",func(): abandon_requested.emit())
	menu_button("EINSTELLUNGEN",func(): show_settings())
	menu_button("BEENDEN",func(): quit_requested.emit())
	_build_settings()
	resized.connect(layout)
	layout()

func menu_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340,52)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font",VisualTheme.serif())
	button.add_theme_font_size_override("font_size",17)
	button.add_theme_stylebox_override("normal",VisualTheme.panel(Color("171a1bd9"),Color("766044"),1))
	button.add_theme_stylebox_override("hover",VisualTheme.panel(Color("433725e8"),Color("c4a16a"),1))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	buttons.add_child(button)
	return button

func layout() -> void:
	if title == null:
		return
	var landscape := size.y < 550 and size.x > size.y
	var width := minf(340,size.x-48)
	var count := 0
	for child in buttons.get_children():
		child.custom_minimum_size = Vector2(width,48)
		if child.visible:
			count += 1
	buttons.size.x = width
	if landscape:
		title.position = Vector2(32,72)
		title.add_theme_font_size_override("font_size",28)
		buttons.position = Vector2(size.x-width-24,maxf(12,(size.y-count*60)/2))
	else:
		var x := 24.0 if size.x < 700 else 100.0
		buttons.position = Vector2(x,maxf(210,size.y-count*60-48))
		title.position = Vector2(x,maxf(64,minf(size.y*0.24,buttons.position.y-180)))
		title.add_theme_font_size_override("font_size",28 if size.x < 700 else 44)
	if settings_panel != null:
		var panel_width := minf(420.0, size.x - 36.0)
		settings_panel.position = (size - Vector2(panel_width, 240.0)) * 0.5
		settings_panel.size = Vector2(panel_width, 240.0)
	queue_redraw()

func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.add_theme_stylebox_override("panel", VisualTheme.panel(Color("111416f5"), Color("a17c49"), 5))
	settings_panel.custom_minimum_size = Vector2(320, 240)
	settings_panel.hide()
	settings_panel.z_index = 20
	add_child(settings_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	settings_panel.add_child(content)
	var heading := VisualTheme.label(content, "EINSTELLUNGEN", 24, Color("ead8b3"), true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	var caption := VisualTheme.label(row, "MUSIK", 15, Color("e7dfca"), true)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_value = VisualTheme.label(row, "35 %", 15, Color("c7a16a"))
	music_value.custom_minimum_size.x = 48
	music_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	music_slider = HSlider.new()
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	music_slider.custom_minimum_size = Vector2(0, 36)
	music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_slider.value_changed.connect(_on_music_slider_changed)
	content.add_child(music_slider)
	var hint := VisualTheme.label(content, "Lautstärke der Musik im Menü und in der Partie", 12, Color("989d9e"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	var back := menu_button("ZURÜCK",func():
		close_settings()
	)
	back.custom_minimum_size = Vector2(0, 44)
	buttons.remove_child(back)
	content.add_child(back)

func show_settings(current_volume: float = -1.0) -> void:
	if current_volume >= 0.0:
		set_music_volume(current_volume)
	buttons.hide()
	settings_panel.show()
	settings_requested.emit()

func close_settings() -> void:
	settings_panel.hide()
	buttons.show()
	settings_closed.emit()

func set_music_volume(value: float) -> void:
	if music_slider == null:
		return
	music_slider.set_value_no_signal(value * 100.0)
	_update_music_value(music_slider.value)

func _on_music_slider_changed(value: float) -> void:
	_update_music_value(value)
	music_volume_changed.emit(value / 100.0)

func _update_music_value(value: float) -> void:
	music_value.text = "%d %%" % roundi(value)

func present(can_resume: bool, current_volume: float = 0.35) -> void:
	settings_panel.hide()
	buttons.show()
	set_music_volume(current_volume)
	play_button.text = "NEUES SPIEL" if can_resume else "SPIELEN"
	resume_button.visible = can_resume
	abandon_button.visible = can_resume
	deck_button.disabled = can_resume
	deck_button.tooltip_text = "Deckbau ist vor der Partie verfügbar. Laufende Partie zuerst beenden." if can_resume else "Startaufstellung bearbeiten."
	show()
	layout()

func _draw() -> void:
	var y := title.position.y-24
	var x := title.position.x
	draw_line(Vector2(x,y),Vector2(x+118,y),Color("987b51"),1,true)
	draw_colored_polygon(PackedVector2Array([Vector2(x+130,y-5),Vector2(x+135,y),Vector2(x+130,y+5),Vector2(x+125,y)]),Color("c4a16a"))
	draw_line(Vector2(x+142,y),Vector2(x+260,y),Color("987b51"),1,true)
