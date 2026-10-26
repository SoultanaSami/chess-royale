class_name StoneFloor
extends RefCounted
## Bevelled limestone and basalt. Surface variation is seeded per tile, never per frame.
static func tile_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var top: Array[Vector3] = [Vector3(-0.545,0.045,-0.545),Vector3(0.545,0.045,-0.545),Vector3(0.545,0.045,0.545),Vector3(-0.545,0.045,0.545)]
	var rim: Array[Vector3] = [Vector3(-0.56,0.022,-0.56),Vector3(0.56,0.022,-0.56),Vector3(0.56,0.022,0.56),Vector3(-0.56,0.022,0.56)]
	var vertices: Array[Vector3] = [top[0],top[2],top[1],top[0],top[3],top[2]]
	for i in range(4):
		var j := (i+1)%4
		vertices.append_array([top[i],rim[j],rim[i],top[i],top[j],rim[j]])
		var a := rim[i]-Vector3(0,0.16,0)
		var b := rim[j]-Vector3(0,0.16,0)
		vertices.append_array([rim[i],b,a,rim[i],rim[j],b])
	# Godot's front faces wind clockwise; keep the cap normal pointing up.
	for i in range(0,vertices.size(),3):
		for vertex in [vertices[i],vertices[i+2],vertices[i+1]]:
			surface.set_uv(Vector2(vertex.x,vertex.z)/1.12+Vector2(0.5,0.5))
			surface.add_vertex(vertex)
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()

static func build(parent: Node3D) -> void:
	var stone := ModelSculptor.material(Color("363530"),0.03,0.6)
	var trim := ModelSculptor.material(Color("635846"),0.12,0.5)
	var brass := ModelSculptor.material(Color("9a7745"),0.72,0.3)
	var shadow := ModelSculptor.material(Color("121617"),0.02,0.95)
	ModelSculptor.box(parent,Vector3(30,0.2,30),Vector3(0,-0.52,0),shadow)
	for row in range(12):
		for col in range(12):
			var center := Vector3((col-5.5)*1.32,-0.38,(row-5.5)*1.32)
			if absf(center.x)<4.8 and absf(center.z)<4.8:
				continue
			var surface := ShaderMaterial.new()
			surface.shader = load("res://shaders/slate.gdshader")
			surface.set_shader_parameter("stone_color",Color("393a35"))
			surface.set_shader_parameter("tile_seed",float(row*12+col+100))
			ModelSculptor.box(parent,Vector3(1.30,0.18,1.30),center,surface)
	ModelSculptor.box(parent,Vector3(10.4,0.18,10.4),Vector3(0,-0.25,0),stone)
	ModelSculptor.box(parent,Vector3(9.92,0.16,9.92),Vector3(0,-0.12,0),trim)
	ModelSculptor.box(parent,Vector3(9.25,0.1,9.25),Vector3(0,-0.08,0),shadow)
	var shape := tile_mesh()
	for row in range(8):
		for col in range(8):
			var material := ShaderMaterial.new()
			material.shader = load("res://shaders/slate.gdshader")
			material.set_shader_parameter("stone_color",Color("504c42") if (row+col)%2==0 else Color("292d2c"))
			material.set_shader_parameter("tile_seed",float(row*8+col))
			ModelSculptor.mesh(parent,shape,Vector3((col-3.5)*1.15,0,(row-3.5)*1.15),material)
	for side in [-1.0,1.0]:
		for offset in [4.65,4.91]:
			ModelSculptor.box(parent,Vector3(0.018,0.012,9.82),Vector3(side*offset,0.025,0),brass)
			ModelSculptor.box(parent,Vector3(9.82,0.012,0.018),Vector3(0,0.025,side*offset),brass)
		for i in range(32):
			var along := -4.6+i*0.295
			ModelSculptor.box(parent,Vector3(0.11,0.008,0.014),Vector3(side*4.78,0.027,along),brass,Vector3(0,PI/4,0))
			ModelSculptor.box(parent,Vector3(0.014,0.008,0.11),Vector3(along,0.027,side*4.78),brass,Vector3(0,PI/4,0))
	for x in [-4.78,4.78]:
		for z in [-4.78,4.78]:
			var medallion := ModelSculptor.cylinder(parent,0.13,0.13,0.012,Vector3(x,0.032,z),brass,8)
			medallion.rotation.y = PI/8
			ModelSculptor.cylinder(parent,0.08,0.08,0.016,Vector3(x,0.035,z),shadow,8)
	for side in [-1.0,1.0]:
		for back in [-1.0,1.0]:
			for i in range(2):
				var candle := CandleProp.new()
				parent.add_child(candle)
				candle.position = Vector3(side*(5.45+i*0.3),-0.28,back*(4.7-i*0.2))
				candle.energy = 1.7 if i==0 else 0.6
				candle.build(0.5+i*0.25,0.10,34+i+int(side*3+back*7),i==0)
