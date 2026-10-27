class_name TacticalBoardInput
extends Control
signal clicked(position: Vector2, shift: bool)
signal hovered(position: Vector2)
signal formation_selected(rect: Rect2)
signal camera_input(event: InputEvent)
signal cancelled
signal card_dropped(slot: int, position: Vector2)
var drop_allowed: Callable
var origin := Vector2.ZERO
var dragging := false
var pressed := false
var pointer := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("battlefield_input", true)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				origin = event.position
				pressed = true
			else:
				if dragging:
					formation_selected.emit(Rect2(origin, event.position - origin).abs())
				elif pressed:
					clicked.emit(event.position, event.shift_pressed)
				pressed = false
				dragging = false
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancelled.emit()
		else:
			camera_input.emit(event)
		accept_event()
	elif event is InputEventMouseMotion:
		pointer = event.position
		if pressed and origin.distance_to(pointer) > 9:
			dragging = true
			queue_redraw()
		camera_input.emit(event)
		hovered.emit(event.position)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		# gui_input handles releases over the board; deferred cleanup also catches HUD releases.
		clear_drag.call_deferred()

func clear_drag() -> void:
	pressed = false
	dragging = false
	queue_redraw()

func _draw() -> void:
	if dragging:
		var rect := Rect2(origin, pointer - origin).abs()
		draw_rect(rect, Color(1, .75, .3, .12))
		draw_rect(rect, VisualTheme.GOLD, false, 2)

func _can_drop_data(position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") == "reserve" and drop_allowed.is_valid() and drop_allowed.call(data.slot, position)

func _drop_data(position: Vector2, data: Variant) -> void:
	card_dropped.emit(data.slot, position)
