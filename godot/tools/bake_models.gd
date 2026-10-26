extends SceneTree

func _initialize() -> void:
	for id in ["phalanx", "cavalry", "assassin", "ram", "trebuchet", "golem", "guard", "queen"]:
		var model := ModelSculptor.build(id)
		set_owners(model, model)
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, "res://assets/models/%s.tscn" % id) == OK)
		model.free()
	print("Baked 8 authored model prefabs.")
	quit()

func set_owners(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		set_owners(child, owner_node)
