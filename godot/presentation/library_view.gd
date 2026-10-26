class_name LibraryView
extends Node3D
## Physical menu set. Seeded books, carved shelves, stone arches and wax candles.
var camera: Camera3D
var rng := RandomNumberGenerator.new()
var wood: ShaderMaterial
var brass: Material
var stone: Material
var dark: Material

func _ready() -> void:
	rng.seed = 1642
	wood = ShaderMaterial.new()
	wood.shader = load("res://shaders/library_wood.gdshader")
	brass = ModelSculptor.material(Color("9b7948"),0.78,0.32)
	stone = ModelSculptor.material(Color("383c3d"),0.05,0.84)
	dark = ModelSculptor.material(Color("151619"),0.4,0.52)
	build_room()
	for x in [-4.1,0.0,4.1]:
		bookshelf(Vector3(x,0,-3.8))
	build_desk()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("090e15")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("889aaa")
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(6.6,3.8,10)
	camera.look_at(global_position+Vector3(0.3,2.3,-1.8))
	camera.fov = 43
	camera.environment = env
	var moon := SpotLight3D.new()
	moon.position = Vector3(-5,5,1)
	add_child(moon)
	moon.look_at(global_position+Vector3(2,0,-2))
	moon.light_color = Color("a5bbd4")
	moon.light_energy = 1.5
	moon.spot_range = 18
	moon.spot_angle = 55
	moon.shadow_enabled = true
	# A broad warm bounce makes leather bindings and carving legible in the shadows.
	var bounce := OmniLight3D.new()
	bounce.position = Vector3(1,3,0)
	bounce.light_color = Color("e9b879")
	bounce.light_energy = 1.1
	bounce.omni_range = 10
	add_child(bounce)
	for i in range(45):
		var dust := ModelSculptor.orb(self,0.006,Vector3(rng.randf_range(-5,5),rng.randf_range(0.5,5),rng.randf_range(-3,2)),ModelSculptor.material(Color("a89470"),0,1,0.2))
		dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_room() -> void:
	ModelSculptor.box(self,Vector3(16,0.3,14),Vector3(0,-0.2,0),stone)
	for row in range(7):
		for col in range(10):
			var tint := Color("454440").darkened(rng.randf_range(0.0,0.25))
			ModelSculptor.box(self,Vector3(1.5,0.05,1.7),Vector3((col-5)*1.52,0,(row-3)*1.72),ModelSculptor.material(tint,0.04,0.55))
	for row in range(9):
		for col in range(14):
			ModelSculptor.box(self,Vector3(1.05,0.64,0.5),Vector3((col-7)*1.08+(0.54 if row%2 else 0.0),row*0.67+0.3,-4.65),stone)
	for x in [-6.25,-2.05,2.05,6.25]:
		ModelSculptor.cylinder(self,0.26,0.23,4.9,Vector3(x,2.45,-3.5),stone,12)
		for y in [0.16,0.32,4.65,4.88]:
			ModelSculptor.box(self,Vector3(0.62,0.13,0.62),Vector3(x,y,-3.5),stone)
	# Rounded rib segments frame the library alcoves.
	for center in [-4.15,0.0,4.15]:
		for i in range(20):
			var a := i*PI/19.0
			ModelSculptor.box(self,Vector3(0.38,0.36,0.5),Vector3(center+cos(a)*2.05,4.7+sin(a)*1.35,-3.45),stone,Vector3(0,0,a-PI/2))
	# Left lancet window and lead lattice.
	var glass := ModelSculptor.material(Color("34465c"),0.15,0.35,0.4)
	ModelSculptor.box(self,Vector3(0.12,3.8,2.5),Vector3(-6.6,3,0.2),dark)
	ModelSculptor.box(self,Vector3(0.14,3.5,2.25),Vector3(-6.55,3,0.2),glass)
	for z in [-0.65,0.2,1.05]:
		ModelSculptor.box(self,Vector3(0.19,3.6,0.06),Vector3(-6.45,3,z),dark)
	for y in [1.5,2.3,3.1,3.9,4.7]:
		ModelSculptor.box(self,Vector3(0.19,0.05,2.3),Vector3(-6.45,y,0.2),dark)

func bookshelf(pos: Vector3) -> void:
	var shelf := Node3D.new()
	add_child(shelf)
	shelf.position = pos
	ModelSculptor.box(shelf,Vector3(3.65,4.65,0.13),Vector3(0,2.45,-0.25),wood)
	for x in [-1.77,1.77]:
		ModelSculptor.box(shelf,Vector3(0.22,4.8,0.75),Vector3(x,2.4,0),wood)
		for strip in [-0.06,0.06]:
			ModelSculptor.box(shelf,Vector3(0.018,4.5,0.025),Vector3(x+strip,2.4,0.4),brass)
	for y in [0.22,1.24,2.26,3.28,4.3,4.85]:
		ModelSculptor.box(shelf,Vector3(3.84,0.13,0.85),Vector3(0,y,0),wood)
		ModelSculptor.box(shelf,Vector3(3.8,0.028,0.035),Vector3(0,y+0.04,0.44),brass)
	# Cornice layers and carved quatrefoil ornaments.
	ModelSculptor.box(shelf,Vector3(3.98,0.13,1.0),Vector3(0,4.99,0),wood)
	for x in [-1.4,-0.7,0.0,0.7,1.4]:
		for d in [Vector2(-0.055,0),Vector2(0.055,0),Vector2(0,-0.055),Vector2(0,0.055)]:
			var ornament := ModelSculptor.orb(shelf,0.065,Vector3(x+d.x,4.6+d.y,0.38),brass)
			ornament.scale.z = 0.25
	for tier in range(4):
		var x := -1.55
		while x < 1.5:
			var width := rng.randf_range(0.13,0.27)
			var height := rng.randf_range(0.58,0.89)
			book(shelf,Vector3(x+width/2,0.3+tier*1.02,0.12),width,height)
			x += width+0.022
	# Single candle on the top shelf; foreground candles carry the detailed lighting.
	add_candle(shelf,Vector3(1.1,4.94,0),0.35,12+int(pos.x*2),false)

func book(parent: Node3D, pos: Vector3, width: float, height: float) -> void:
	var colors: Array[Color] = [Color("3c2722"),Color("283532"),Color("433626"),Color("43232a"),Color("24303a"),Color("5b4630")]
	var leather := ModelSculptor.material(colors[rng.randi_range(0,colors.size()-1)],0.08,0.6)
	var paper := ModelSculptor.material(Color("a99b77"),0,0.92)
	ModelSculptor.box(parent,Vector3(width,height,0.52),pos+Vector3(0,height/2,0),leather)
	ModelSculptor.box(parent,Vector3(width*0.8,0.016,0.46),pos+Vector3(0,height-0.012,0),paper)
	for y in [0.09,height*0.33,height*0.77,height-0.07]:
		ModelSculptor.box(parent,Vector3(width+0.015,0.024,0.025),pos+Vector3(0,y,0.27),brass)
	for y in [height*0.48,height*0.55,height*0.62]:
		ModelSculptor.box(parent,Vector3(width*0.54,0.007,0.008),pos+Vector3(0,y,0.28),brass)
	if rng.randf() > 0.6:
		ModelSculptor.box(parent,Vector3(0.035,0.065,0.02),pos+Vector3(0,height*0.2,0.28),brass,Vector3(0,0,PI/4))

func add_candle(parent: Node3D, pos: Vector3, height: float, candle_seed: int, light: bool = true) -> void:
	var candle := CandleProp.new()
	parent.add_child(candle)
	candle.position = pos
	candle.build(height,0.11,candle_seed,light)

func build_desk() -> void:
	var desk := Node3D.new()
	add_child(desk)
	desk.position = Vector3(1.7,0,1.1)
	desk.rotation.y = -0.13
	ModelSculptor.box(desk,Vector3(5.6,0.19,2.5),Vector3(0,1.25,0),wood)
	for x in [-2.45,2.45]:
		ModelSculptor.box(desk,Vector3(0.25,1.2,1.8),Vector3(x,0.6,0),wood)
		ModelSculptor.box(desk,Vector3(0.44,0.15,2.1),Vector3(x,0.12,0),wood)
	ModelSculptor.box(desk,Vector3(5.3,0.25,0.1),Vector3(0,1.05,1.05),wood)
	for x in [-2.1,-1.4,-0.7,0.0,0.7,1.4,2.1]:
		ModelSculptor.box(desk,Vector3(0.09,0.09,0.025),Vector3(x,1.06,1.12),brass,Vector3(0,0,PI/4))
	# Large opened manuscript with layered pages, raised spine and ink rules.
	var parchment := ModelSculptor.material(Color("c1aa7a"),0,0.82)
	var ink := ModelSculptor.material(Color("413329"),0,0.95)
	var cover := ModelSculptor.material(Color("382820"),0.1,0.56)
	for side in [-1.0,1.0]:
		var page := Node3D.new()
		desk.add_child(page)
		page.position = Vector3(side*0.46,1.39,0.25)
		page.rotation.z = side*0.055
		ModelSculptor.box(page,Vector3(0.91,0.06,1.15),Vector3.ZERO,cover)
		ModelSculptor.box(page,Vector3(0.84,0.065,1.08),Vector3(0,0.045,0),parchment)
		for i in range(15):
			var length := rng.randf_range(0.45,0.68)
			ModelSculptor.box(page,Vector3(length,0.002,0.009),Vector3(0,0.08,-0.38+i*0.054),ink)
		for i in range(4):
			ModelSculptor.box(page,Vector3(0.84,0.002,0.008),Vector3(0,0.027+i*0.012,0.54),ink)
	ModelSculptor.box(desk,Vector3(0.055,0.01,1.3),Vector3(0.1,1.5,0.3),ModelSculptor.material(Color("702a26")))
	# Stacked leather folios with gilded corners.
	for i in range(3):
		var stack := Node3D.new()
		desk.add_child(stack)
		stack.position = Vector3(-1.8,1.39+i*0.16,-0.2)
		stack.rotation.y = -0.2+i*0.18
		ModelSculptor.box(stack,Vector3(0.86,0.15,0.64),Vector3.ZERO,cover)
		ModelSculptor.box(stack,Vector3(0.81,0.09,0.6),Vector3(0,0,0.025),parchment)
		for x in [-0.37,0.37]:
			ModelSculptor.box(stack,Vector3(0.09,0.012,0.11),Vector3(x,0.08,0.24),brass)
	# Brass inkpot, feather quill and three nonidentical melted candles.
	ModelSculptor.cylinder(desk,0.13,0.09,0.17,Vector3(1.0,1.44,0.05),brass,24)
	var feather := ModelSculptor.orb(desk,0.07,Vector3(1.13,1.85,-0.02),parchment)
	feather.scale = Vector3(0.7,4.5,0.15)
	feather.rotation.z = -0.3
	add_candle(desk,Vector3(1.8,1.35,0.54),0.72,71)
	add_candle(desk,Vector3(2.25,1.35,0.12),0.47,72)
	add_candle(desk,Vector3(1.58,1.35,-0.25),0.93,73)
	add_candle(self,Vector3(-2.7,0.02,-0.4),0.56,74)
