class_name ReserveCard
extends Button
signal drag_started(slot: int)
var slot: int

func _get_drag_data(_position: Vector2) -> Variant:
	if disabled:
		return null
	var preview := Label.new()
	preview.text = tooltip_text.split("\n")[0]
	preview.add_theme_color_override("font_color", VisualTheme.GOLD)
	set_drag_preview(preview)
	drag_started.emit(slot)
	return {"kind": "reserve", "slot": slot}
