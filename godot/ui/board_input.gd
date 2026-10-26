class_name BoardInput
extends Control
signal square_clicked(position: Vector2)
signal square_hovered(position: Vector2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		square_clicked.emit(event.position)
	if event is InputEventMouseMotion:
		square_hovered.emit(event.position)
