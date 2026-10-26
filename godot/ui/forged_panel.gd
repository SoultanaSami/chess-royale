class_name ForgedPanel
extends Panel
## Restrained leather grain, stitched seams and iron rivets drawn at native UI resolution.
func _draw() -> void:
	for y in range(15, int(size.y) - 12, 11):
		for x in range(12, int(size.x) - 12, 19):
			var shift := sin(float(x * 17 + y * 13)) * 3.0
			draw_line(Vector2(x + shift, y), Vector2(x + shift + 4, y + 1), Color(0.65, 0.48, 0.3, 0.045), 1)
	for y in [9.0, size.y - 9]:
		draw_line(Vector2(9, y), Vector2(size.x - 9, y), Color("594a36"), 1)
		for x in range(19, int(size.x) - 19, 14):
			draw_line(Vector2(x, y + 3), Vector2(x + 5, y + 3), Color("403b32"), 1)
	for x in range(12, int(size.x), 120):
		for y in [5.0, size.y - 5]:
			draw_circle(Vector2(x, y), 3, Color("080d11"))
			draw_circle(Vector2(x, y - 0.5), 2, Color("867050"))
