class_name ReserveCard
extends Button
signal drag_started(slot: int)
var slot: int
var data: UnitData
var portrait: TextureRect
var title_label: Label
var home := Vector2.ZERO
var lift: float = 0
var glow: float = 0
var _hover := false
var _chosen := false
var _affordable := true
var _animation: Tween
const EMBLEMS := ["♟", "♞", "♝", "♜", "♛"]

func _ready() -> void:
	mouse_entered.connect(func(): _hover = true; animate_card())
	mouse_exited.connect(func(): _hover = false; animate_card())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("11141ced")
		style.border_color = Color("765e3b") if state != "disabled" else Color("373b40")
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		style.corner_detail = 1
		style.shadow_color = Color(0,0,0,.75)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0,5)
		add_theme_stylebox_override(state,style)
	portrait = TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.clip_contents = true
	add_child(portrait)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float saturation = 1.; void fragment(){ vec4 c=texture(TEXTURE,UV); float g=dot(c.rgb,vec3(.299,.587,.114)); COLOR=vec4(mix(vec3(g),c.rgb,saturation),c.a)*COLOR; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	portrait.material = material
	title_label = VisualTheme.label(self,"",12,VisualTheme.CREAM,true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(layout)
	layout()

func layout() -> void:
	pivot_offset = Vector2(size.x*.5,size.y)
	if portrait != null:
		portrait.position = Vector2(7,37)
		portrait.size = Vector2(size.x-14,size.y-74)
		title_label.position = Vector2(6,size.y-35)
		title_label.size = Vector2(size.x-12,30)
	queue_redraw()

func configure(unit: UnitData, texture: Texture2D) -> void:
	data = unit
	portrait.texture = texture
	title_label.text = unit.unit_name
	tooltip_text = "%s\n%d Gold + 1 KP · Bewegung %d · Angriff %d\nNeben deiner Burg rekrutieren" % [unit.unit_name,unit.resource_cost,unit.max_move_range,unit.attack_range]
	queue_redraw()

func set_state(affordable: bool, chosen: bool) -> void:
	if affordable == _affordable and chosen == _chosen: return
	_affordable = affordable
	_chosen = chosen
	disabled = not affordable
	portrait.material.set_shader_parameter("saturation",1.0 if affordable else 0.0)
	portrait.modulate = Color.WHITE if affordable else Color(.42,.42,.42,.8)
	animate_card()

func animate_card() -> void:
	if _animation != null: _animation.kill()
	var raised := _hover or _chosen
	z_index = 10 if raised else 0
	_animation = create_tween().set_parallel(true)
	_animation.tween_property(self,"lift",30.0 if raised else 0.0,.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation.tween_property(self,"scale",Vector2.ONE*(1.12 if raised else 1.0),.14)
	_animation.tween_property(self,"glow",1.0 if raised and _affordable else 0.0,.14)

func _process(_delta: float) -> void:
	position = home - Vector2(0,lift)
	queue_redraw()

func _draw() -> void:
	var bronze := Color("a57f4a").lerp(Color("ffce77"),glow)
	if not _affordable: bronze = Color("50535b")
	draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),Color(bronze,.35+glow*.5),false,1)
	for x in [8.0,size.x-8]:
		for y in [8.0,size.y-8]:
			var inward := Vector2(1 if x<20 else -1,1 if y<20 else -1)
			draw_line(Vector2(x,y),Vector2(x+inward.x*15,y),bronze,3,true)
			draw_line(Vector2(x,y),Vector2(x,y+inward.y*15),bronze,3,true)
	var hex := PackedVector2Array()
	var center := Vector2(25,24)
	for i in range(6): hex.append(center+Vector2(cos(i*TAU/6),sin(i*TAU/6))*19)
	draw_colored_polygon(hex,Color("795224") if _affordable else Color("282c32"))
	var border := hex.duplicate(); border.append(hex[0])
	draw_polyline(border,bronze,2,true)
	var font := VisualTheme.serif()
	if data != null:
		var number := str(data.resource_cost)
		draw_string(font,center-Vector2(font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x/2,-7),number,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ffe1a3"))
		var symbol: String = EMBLEMS[data.chess_role]
		var symbols := ThemeDB.fallback_font
		draw_string(symbols,Vector2(size.x*.5-12,32),symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,28,bronze)
	draw_string(VisualTheme.body(),Vector2(size.x-26,23),str(slot+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,VisualTheme.MUTED)

func _get_drag_data(_position: Vector2) -> Variant:
	if disabled: return null
	var preview := TextureRect.new()
	preview.texture = portrait.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(90,110)
	preview.modulate.a = .8
	set_drag_preview(preview)
	drag_started.emit(slot)
	return {"kind":"reserve","slot":slot}
