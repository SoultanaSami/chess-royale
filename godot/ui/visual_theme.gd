class_name VisualTheme
extends RefCounted

const GOLD := Color("c7a16a")
const CREAM := Color("e7dfca")
const MUTED := Color("989d9e")
const DARK := Color("11171b")

static func serif() -> Font:
	return load("res://assets/fonts/cinzel-600.ttf")

static func body() -> Font:
	return load("res://assets/fonts/inter-400.ttf")

static func panel(color: Color = DARK, border: Color = Color("594a36"), radius: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = body()
	result.default_font_size = 14
	result.set_constant("v_separation", "PopupMenu", 32)
	result.set_color("font_color", "Label", CREAM)
	result.set_color("font_color", "Button", CREAM)
	result.set_color("font_hover_color", "Button", Color("fff1ce"))
	result.set_color("font_disabled_color", "Button", Color("666b6d"))
	result.set_stylebox("normal", "Button", panel(Color("222426")))
	result.set_stylebox("hover", "Button", panel(Color("34312a"), GOLD))
	result.set_stylebox("pressed", "Button", panel(Color("50402c"), GOLD))
	result.set_stylebox("focus", "Button", panel(Color(0, 0, 0, 0), Color("ffe1a3")))
	result.set_stylebox("disabled", "Button", panel(Color("15191d"), Color("343638")))
	result.set_stylebox("panel", "PanelContainer", panel())
	result.set_stylebox("panel", "TooltipPanel", panel(Color("151a1f"), GOLD))
	result.set_color("font_color", "TooltipLabel", CREAM)
	return result

static func label(parent: Node, text: String, font_size: int = 16, color: Color = CREAM, title: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", serif() if title else body())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
