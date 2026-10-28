class_name BattleDecal
extends RefCounted
static func material(color: Color, pattern: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tactical_decal.gdshader")
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("pattern", pattern)
	return mat

static func create(board: BoardState, cell: Vector2i, mat: Material, height: float = .035) -> MeshInstance3D:
	var points := BattlefieldTerrainView.corners(board, cell, height)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv := [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]
	for index in [0,1,2,0,2,3]:
		surface.set_uv(uv[index])
		surface.set_normal(Vector3.UP)
		surface.add_vertex(points[index])
	var result := MeshInstance3D.new()
	result.mesh = surface.commit()
	result.material_override = mat
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result
