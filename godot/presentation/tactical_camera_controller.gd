class_name TacticalCameraController
extends Node
## Mouse and keyboard camera, independent of unit selection and game rules.
@export var pan_speed: float = 9.0
@export var edge_pan_pixels: float = 18.0
@export var edge_pan_enabled: bool = true
var camera: Camera3D
var board: BoardState
var bounds: Vector2
var focus := Vector3.ZERO
var yaw: float = 0.0
var tilt: float = deg_to_rad(52)
var distance: float = 28.0
var home_distance: float = 28.0
var orbiting: bool = false
var controls_enabled: bool = true
var shake_remaining: float = 0

func shake() -> void:
	shake_remaining = .15

func setup(view: BoardView) -> void:
	camera = view.camera
	board = view.terrain_board
	bounds = Vector2(view.grid_columns, view.grid_rows) * BoardView.SPACING * .5
	home_distance = maxf(20.0, maxf(bounds.x, bounds.y) * 3.2)
	focus_base(0)

func focus_base(side: int) -> void:
	var cell := TacticalCommands.castle(board, side)
	focus = BoardView.world_position(cell, board.rows, board.columns) + Vector3(2 if side == 0 else -2, board.surface_height(cell) + .4, -1 if side == 0 else 1)
	yaw = 0 if side == 0 else PI
	tilt = deg_to_rad(52)
	distance = 22
	update_camera()

func reset_view() -> void:
	focus = Vector3(0, 0, bounds.y * .22)
	yaw = 0
	tilt = deg_to_rad(52)
	distance = home_distance
	update_camera()

func _process(delta: float) -> void:
	shake_remaining = maxf(0,shake_remaining-delta)
	if not controls_enabled or camera == null or not get_window().has_focus():
		orbiting = false
		return
	var movement := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): movement.x -= 1
	if Input.is_physical_key_pressed(KEY_D): movement.x += 1
	if Input.is_physical_key_pressed(KEY_W): movement.y -= 1
	if Input.is_physical_key_pressed(KEY_S): movement.y += 1
	var pointer := get_viewport().get_mouse_position()
	var size := get_viewport().get_visible_rect().size
	var hovered := get_viewport().gui_get_hovered_control()
	if edge_pan_enabled and not orbiting and (hovered == null or hovered.has_meta("battlefield_input")) and Rect2(Vector2.ZERO, size).has_point(pointer):
		if pointer.x < edge_pan_pixels: movement.x -= 1
		if pointer.x > size.x - edge_pan_pixels: movement.x += 1
		if pointer.y < edge_pan_pixels: movement.y -= 1
		if pointer.y > size.y - edge_pan_pixels: movement.y += 1
	movement = movement.limit_length()
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var backward := Vector3(sin(yaw), 0, cos(yaw))
	focus += (right * movement.x + backward * movement.y) * delta * pan_speed * distance / home_distance
	focus.x = clampf(focus.x, -bounds.x, bounds.x)
	focus.z = clampf(focus.z, -bounds.y, bounds.y)
	update_camera()

func _input(event: InputEvent) -> void:
	# Release over HUD controls must still end a drag.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		orbiting = false

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or camera == null:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: orbiting = true
			MOUSE_BUTTON_WHEEL_UP: distance = maxf(8.0, distance * .9)
			MOUSE_BUTTON_WHEEL_DOWN: distance = minf(home_distance * 2, distance / .9)
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and orbiting:
		yaw -= event.relative.x * .004
		tilt = clampf(tilt + event.relative.y * .004, deg_to_rad(25), deg_to_rad(80))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		reset_view()
	update_camera()

func update_camera() -> void:
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 38
	camera.far = 300
	camera.position = focus + Vector3(sin(yaw) * cos(tilt), sin(tilt), cos(yaw) * cos(tilt)) * distance
	camera.look_at(focus)
	if shake_remaining > 0:
		var time := Time.get_ticks_msec()*.001
		camera.position += camera.basis.x*sin(time*81)*shake_remaining*.45 + Vector3.UP*cos(time*67)*shake_remaining*.23
