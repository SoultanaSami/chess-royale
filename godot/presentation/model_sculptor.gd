class_name ModelSculptor
extends RefCounted
## Authored low-poly silhouettes, baked as interchangeable PackedScene prefabs.
## No game rules are allowed here. A GLB can replace any catalog model path.

static func material(color: Color, metal: float = 0.0, rough: float = 0.6, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = rough
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	node.position = pos
	node.rotation = rotation
	parent.add_child(node)
	return node

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, mat, rotation)

static func cylinder(parent: Node3D, bottom: float, top: float, height: float, pos: Vector3, mat: Material, sides: int = 12) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = sides
	return mesh(parent, shape, pos, mat)

static func orb(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 12
	shape.rings = 6
	return mesh(parent, shape, pos, mat)

static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id.to_pascal_case()
	var iron := material(Color("555d66"), 0.78, 0.32)
	var edge := material(Color("a9a8a0"), 0.72, 0.28)
	var gold := material(Color("bd9153"), 0.7, 0.3)
	var dark := material(Color("161d25"), 0.55)
	var leather := material(Color("402a22"))
	var cloth := material(Color("542333"), 0.0, 0.92)
	var stone := material(Color("555c5c"), 0.2, 0.88)
	var glow := material(Color("ffad44"), 0.2, 0.3, 2.4)
	var jade := material(Color("55bdad"), 0.3, 0.3, 1.8)
	match id:
		"phalanx", "guard", "assassin", "queen":
			var tall := 1.15 if id in ["guard", "queen"] else 0.88
			# Greaves, layered cuirass, articulated shoulders and helmet.
			for side in [-1.0, 1.0]:
				box(root, Vector3(0.13, 0.27, 0.18), Vector3(side * 0.12, 0.18, 0), iron)
				box(root, Vector3(0.16, 0.09, 0.24), Vector3(side * 0.12, 0.06, -0.04), dark)
			cylinder(root, 0.27, 0.16, tall * 0.45, Vector3(0, 0.36, 0.02), cloth if id != "phalanx" else iron, 8)
			cylinder(root, 0.19, 0.26, 0.3, Vector3(0, tall * 0.59, 0), dark if id == "assassin" else iron, 6)
			box(root, Vector3(0.09, 0.27, 0.035), Vector3(0, tall * 0.61, -0.19), gold)
			for side in [-1.0, 1.0]:
				orb(root, 0.14, Vector3(side * 0.25, tall * 0.71, 0), iron)
				box(root, Vector3(0.10, 0.28, 0.12), Vector3(side * 0.29, tall * 0.52, 0), iron, Vector3(0, 0, side * 0.17))
			cylinder(root, 0.15, 0.12, 0.24, Vector3(0, tall * 0.91, 0), dark if id == "assassin" else edge, 8)
			box(root, Vector3(0.21, 0.035, 0.025), Vector3(0, tall * 0.93, -0.135), jade if id == "assassin" else glow)
			if id == "assassin":
				cylinder(root, 0.2, 0.0, 0.26, Vector3(0, tall * 1.06, 0.02), dark, 6)
				for side in [-1.0, 1.0]:
					box(root, Vector3(0.035, 0.32, 0.06), Vector3(side * 0.33, 0.32, -0.13), jade, Vector3(0.4, 0, side * 0.35))
			elif id == "queen":
				cylinder(root, 0.31, 0.16, 0.58, Vector3(0, 0.29, 0.08), cloth, 8)
				cylinder(root, 0.025, 0.025, 1.3, Vector3(0.36, 0.68, -0.05), gold)
				orb(root, 0.12, Vector3(0.36, 1.38, -0.05), glow)
			else:
				# Tower shield with brass rim and raised central boss.
				box(root, Vector3(0.4, 0.58, 0.08), Vector3(-0.25, 0.5, -0.2), gold)
				box(root, Vector3(0.34, 0.5, 0.09), Vector3(-0.25, 0.5, -0.22), cloth if id == "guard" else dark)
				box(root, Vector3(0.045, 0.44, 0.04), Vector3(-0.25, 0.5, -0.29), edge)
				box(root, Vector3(0.28, 0.045, 0.04), Vector3(-0.25, 0.56, -0.29), edge)
				box(root, Vector3(0.04, 0.98, 0.045), Vector3(0.32, 0.64, -0.09), gold)
				cylinder(root, 0.08, 0.0, 0.25, Vector3(0.32, 1.24, -0.09), edge, 4)
			if id in ["queen", "guard"]:
				cylinder(root, 0.17, 0.18, 0.08, Vector3(0, tall * 1.04, 0), gold)
				for i in range(5):
					var angle := i * TAU / 5.0
					cylinder(root, 0.045, 0, 0.18, Vector3(cos(angle) * 0.16, tall * 1.13, sin(angle) * 0.16), gold, 4)
		"cavalry":
			# Barded horse, four legs, long neck, rider and spear.
			for x in [-0.18, 0.18]:
				for z in [-0.24, 0.24]:
					box(root, Vector3(0.11, 0.39, 0.13), Vector3(x, 0.24, z), iron, Vector3(-z * 0.7, 0, 0))
					box(root, Vector3(0.13, 0.08, 0.17), Vector3(x, 0.05, z - 0.03), dark)
			var body := orb(root, 0.29, Vector3(0, 0.52, 0), iron)
			body.scale = Vector3(0.85, 0.9, 1.5)
			box(root, Vector3(0.25, 0.45, 0.25), Vector3(0, 0.78, -0.28), edge, Vector3(-0.35, 0, 0))
			box(root, Vector3(0.22, 0.2, 0.4), Vector3(0, 0.98, -0.4), iron, Vector3(0.2, 0, 0))
			for x in [-0.08, 0.08]:
				cylinder(root, 0.05, 0, 0.19, Vector3(x, 1.15, -0.32), gold, 4)
				orb(root, 0.025, Vector3(x * 1.5, 1.01, -0.47), glow)
			box(root, Vector3(0.34, 0.06, 0.28), Vector3(0, 0.75, 0.06), leather)
			cylinder(root, 0.17, 0.21, 0.3, Vector3(0, 0.93, 0.09), dark, 6)
			orb(root, 0.13, Vector3(0, 1.18, 0.09), edge)
			box(root, Vector3(0.025, 1.3, 0.025), Vector3(0.29, 0.86, 0.02), gold, Vector3(-0.22, 0, 0))
			cylinder(root, 0.07, 0, 0.24, Vector3(0.29, 1.59, -0.15), edge, 4)
		"ram", "trebuchet":
			for x in [-0.3, 0.3]:
				for z in [-0.29, 0.29]:
					var wheel := cylinder(root, 0.17, 0.17, 0.11, Vector3(x, 0.19, z), dark)
					wheel.rotation.z = PI / 2.0
					orb(root, 0.055, Vector3(x * 1.2, 0.19, z), gold)
			box(root, Vector3(0.53, 0.13, 0.72), Vector3(0, 0.3, 0), leather)
			if id == "ram":
				for x in [-0.22, 0.22]:
					box(root, Vector3(0.08, 0.48, 0.08), Vector3(x, 0.6, 0.21), gold)
				var beam := cylinder(root, 0.15, 0.15, 0.84, Vector3(0, 0.57, -0.08), leather)
				beam.rotation.x = PI / 2.0
				box(root, Vector3(0.36, 0.32, 0.25), Vector3(0, 0.57, -0.47), iron)
				for x in [-0.1, 0.1]:
					orb(root, 0.035, Vector3(x, 0.64, -0.6), glow)
				box(root, Vector3(0.67, 0.08, 0.7), Vector3(0, 0.87, 0), dark, Vector3(0, 0, 0.08))
			else:
				for x in [-0.23, 0.23]:
					box(root, Vector3(0.07, 0.8, 0.09), Vector3(x, 0.68, 0.05), gold, Vector3(0.2, 0, x * 0.5))
				box(root, Vector3(0.08, 1.14, 0.08), Vector3(0, 0.88, -0.12), leather, Vector3(-0.7, 0, 0))
				box(root, Vector3(0.27, 0.27, 0.23), Vector3(0, 0.49, 0.2), stone)
				orb(root, 0.12, Vector3(0, 1.32, -0.48), glow)
		"golem":
			for side in [-1.0, 1.0]:
				box(root, Vector3(0.22, 0.3, 0.28), Vector3(side * 0.19, 0.19, 0), stone)
				box(root, Vector3(0.25, 0.2, 0.27), Vector3(side * 0.4, 0.51, 0), dark)
				box(root, Vector3(0.23, 0.32, 0.28), Vector3(side * 0.35, 0.77, 0), stone, Vector3(0, 0, side * 0.2))
			cylinder(root, 0.3, 0.37, 0.53, Vector3(0, 0.66, 0), stone, 6)
			orb(root, 0.13, Vector3(0, 0.68, -0.28), glow)
			cylinder(root, 0.23, 0.26, 0.3, Vector3(0, 1.06, 0), stone, 8)
			for i in range(6):
				var angle := i * TAU / 6.0
				box(root, Vector3(0.11, 0.15, 0.11), Vector3(cos(angle) * 0.22, 1.26, sin(angle) * 0.22), stone)
			box(root, Vector3(0.25, 0.035, 0.02), Vector3(0, 1.09, -0.24), glow)
	return root
