class_name CardControl
extends Control

signal chosen(index: int)
signal drag_started(index: int)
var data: PieceVariantData
var card_index: int = 0
var selected: bool = false
var playable: bool = true
var deck_mode: bool = false
var hovered: bool = false
var artwork: Texture2D
var hover_tween: Tween
var deck_order: int = -1

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "%s\n%s" % [data.display_name, data.description]
	mouse_entered.connect(func(): set_hover(true))
	mouse_exited.connect(func(): set_hover(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func set_hover(value: bool) -> void:
	hovered = value
	z_index = 10 if value else 0
	if hover_tween != null:
		hover_tween.kill()
	pivot_offset = Vector2(size.x * 0.5, size.y)
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2.ONE * (1.055 if value else 1.0), 0.12)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]):
		chosen.emit(card_index)
		accept_event()

func _get_drag_data(_at_position: Vector2):
	if deck_mode or not playable:
		return null
	drag_started.emit(card_index)
	var preview := Label.new()
	preview.text = data.display_name
	preview.add_theme_color_override("font_color", VisualTheme.GOLD)
	set_drag_preview(preview)
	return {"card_index": card_index}

func _draw() -> void:
	if data == null:
		return
	var w := size.x
	var h := size.y
	var edge := Color("edbd77") if selected or hovered or has_focus() else Color("736048")
	draw_style_box(VisualTheme.panel(Color("161c20"), edge), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(5, 5, w - 10, h - 10), Color("393c39"), false, 1)
	var art_bottom := h * (0.55 if deck_mode else 0.58)
	draw_rect(Rect2(8, 8, w - 16, art_bottom - 8), Color("242b2c"))
	# Engraved halo and rays sit behind the physical model portrait.
	var center := Vector2(w * 0.5, art_bottom * 0.53)
	for radius in [w * 0.32, w * 0.37]:
		draw_arc(center, radius, 0, TAU, 64, Color("66533b"), 1, true)
	for i in range(12):
		var angle := i * TAU / 12.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * w * 0.32, center + direction * w * 0.37, Color("66533b"), 1, true)
	if artwork != null:
		draw_texture_rect(artwork, Rect2(w * 0.13, 5, w * 0.76, art_bottom - 4), false)
	else:
		var color := Color("e9aa57") if data.id == "protect" else Color("86cbb7")
		for radius in [22, 30, 40]:
			draw_arc(center, radius, 0, TAU, 6, color, 2.0, true)
		draw_string(VisualTheme.serif(), center + Vector2(-12, 12), "✦", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, color)
	draw_line(Vector2(8, art_bottom), Vector2(w - 8, art_bottom), edge, 1)
	var font := VisualTheme.serif()
	var name_size := 13 if w < 190 else 14
	# Two-line names preserve readable artwork on compact hand cards.
	var words := data.display_name.split(" ")
	var last: String = words[words.size() - 1]
	var first := data.display_name.trim_suffix(" " + last)
	draw_string(font, Vector2(10, art_bottom + 19), first, HORIZONTAL_ALIGNMENT_CENTER, w - 20, name_size, VisualTheme.CREAM)
	draw_string(font, Vector2(10, art_bottom + 36), last, HORIZONTAL_ALIGNMENT_CENTER, w - 20, name_size, VisualTheme.CREAM)
	if deck_mode:
		draw_multiline_string(VisualTheme.body(), Vector2(13, art_bottom + 55), data.description, HORIZONTAL_ALIGNMENT_CENTER, w - 26, 11, 4, Color("b7b5a8"), TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY)
	var stats := "SCHACHFIGUR" if data.kind == "unit" else "ZAUBER · GEPLANT"
	draw_string(VisualTheme.body(), Vector2(10, h - 15), stats, HORIZONTAL_ALIGNMENT_CENTER, w - 20, 12, VisualTheme.GOLD)
	# Class stamp replaces the removed resource cost.
	var symbol: String = {"PAWN":"P", "KNIGHT":"N", "BISHOP":"B", "ROOK":"R", "KING":"K", "QUEEN":"Q", "SPELL":"✦"}[data.base_chess_type]
	draw_circle(Vector2(24, 24), 17, Color("10171d"))
	draw_arc(Vector2(24, 24), 17, 0, TAU, 32, edge, 1, true)
	draw_string(font, Vector2(8, 31), symbol, HORIZONTAL_ALIGNMENT_CENTER, 32, 19, VisualTheme.GOLD)
	if deck_mode and deck_order >= 0:
		draw_rect(Rect2(w - 55, art_bottom - 22, 47, 20), Color("161c20"))
		draw_string(VisualTheme.body(), Vector2(w - 53, art_bottom - 7), "× %d" % (deck_order + 1), HORIZONTAL_ALIGNMENT_CENTER, 43, 10, VisualTheme.GOLD)
	for x in [7.0, w - 7]:
		for y in [7.0, h - 7]:
			draw_circle(Vector2(x, y), 2, Color("9d8765"))
	if selected:
		draw_rect(Rect2(1, 1, w - 2, h - 2), edge, false, 2)
	if not playable and not deck_mode:
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.025, 0.03, 0.48))
