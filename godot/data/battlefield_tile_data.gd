class_name BattlefieldTileData
extends Resource
## Godot already has a native TileData class. Use this name for 3D battlefield tiles.
enum Terrain { STANDARD, IMPASSABLE, RIVER, RESOURCE_NODE, CASTLE, VOID }

@export var terrain: Terrain = Terrain.STANDARD
@export var road: bool = false
@export var forest: bool = false
@export_range(0, 2) var elevation: int = 0
@export var ramp: bool = false
## Direction from this lower ramp tile toward its higher neighbor.
@export var ramp_direction := Vector2i.ZERO
@export_range(-1, 1) var owner: int = -1
@export_range(0, 99) var resource_yield: int = 1
@export_range(0, 99) var garrison_shields: int = 3

func is_walkable() -> bool:
	return terrain not in [Terrain.IMPASSABLE, Terrain.RIVER, Terrain.VOID]
