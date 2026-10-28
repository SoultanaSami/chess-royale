class_name TacticalCrest
extends Control
var economy := true
var caption: Label
var gold_display: float = 0
var gold_target: int = -1
var income: int = 0
var mine_count: int = 0
var cp: int = 3
var max_cp: int = 3
var shields: Array[int] = [3,3]
var _gold_tween: Tween
var shards: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	caption = VisualTheme.label(self,"",14,VisualTheme.CREAM,true)
	caption.position = Vector2(18,10)
	caption.size = Vector2(size.x-36,42)

func update_economy(amount: int, yield_value: int, mines: int, points: int, maximum: int) -> void:
	income = yield_value
	mine_count = mines
	if amount != gold_target:
		gold_target = amount
		if _gold_tween != null: _gold_tween.kill()
		_gold_tween = create_tween()
		_gold_tween.tween_property(self,"gold_display",float(amount),.28).set_trans(Tween.TRANS_QUAD)
	if points < cp:
		for i in range(points,cp):
			shards.append({"index":i,"age":0.0})
	cp = points
	max_cp = maximum

func _process(delta: float) -> void:
	for shard in shards: shard.age += delta
	shards = shards.filter(func(shard): return shard.age < .35)
	queue_redraw()

func _draw() -> void:
	var w := size.x; var h := size.y
	var shape := PackedVector2Array([Vector2(0,0),Vector2(w-22,0),Vector2(w,19),Vector2(w,h-17),Vector2(w-18,h),Vector2(18,h),Vector2(0,h-16)])
	draw_colored_polygon(shape,Color("111722ed"))
	var outline := shape.duplicate(); outline.append(shape[0])
	draw_polyline(outline,Color("8d7049"),1.5,true)
	draw_line(Vector2(14,h-6),Vector2(w-28,h-6),Color("463c31"),1)
	var font := VisualTheme.body()
	if economy:
		draw_circle(Vector2(27,62),10,Color("be8e35"))
		draw_arc(Vector2(27,62),7,0,TAU,24,Color("ffe0a0"),1.2,true)
		draw_string(VisualTheme.serif(),Vector2(45,70),str(roundi(gold_display)),HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("ffe2a4"))
		draw_string(font,Vector2(112,66),"+%d / Zug  ·  %d Minen" % [income,mine_count],HORIZONTAL_ALIGNMENT_LEFT,-1,12,VisualTheme.MUTED)
		for i in range(max_cp): diamond(Vector2(29+i*29,98),8,Color("67d9ff") if i<cp else Color("2e3540"))
		draw_string(font,Vector2(32+max_cp*29,103),"KOMMANDOS",HORIZONTAL_ALIGNMENT_LEFT,-1,10,VisualTheme.MUTED)
		for shard in shards:
			for k in range(5):
				var angle := k*TAU/5
				var origin := Vector2(29+shard.index*29,98)
				var at: Vector2 = origin+Vector2(cos(angle),sin(angle))*shard.age*65
				diamond(at,2.3,Color(.5,.85,1,1-shard.age/.35))
	else:
		for side in [0,1]:
			for i in range(3):
				diamond(Vector2(222+i*26,33+side*49),9,Color("79caff") if side==0 and i<shields[side] else Color("ed8068") if i<shields[side] else Color("2e3540"))

func diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center-Vector2(radius,0)])
	draw_colored_polygon(points,color)
	draw_line(points[0],points[1],color.lightened(.4),1,true)
	draw_line(points[0],points[3],color.lightened(.3),1,true)
