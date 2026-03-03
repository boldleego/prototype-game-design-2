extends Node3D

const ShotPalette = preload("res://scripts/shot_palette.gd")

@export var tile_scene: PackedScene
@export var tile_radius: float = 0.95
@export var row_depth: float = 1.18
@export var column_offset: float = 0.95

var _layout := [
	Vector2i(-2, 0),
	Vector2i(-1, 0),
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(-2, 1),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(-2, 2),
	Vector2i(-1, 2),
	Vector2i(0, 2),
	Vector2i(1, 2),
	Vector2i(2, 2),
	Vector2i(-2, 3),
	Vector2i(-1, 3),
	Vector2i(0, 3),
	Vector2i(1, 3),
]


func _ready() -> void:
	_spawn_tiles()


func _spawn_tiles() -> void:
	if tile_scene == null:
		return

	for child in get_children():
		child.queue_free()

	for coord in _layout:
		var tile := tile_scene.instantiate() as Node3D
		if tile == null:
			continue

		add_child(tile)
		tile.position = _coord_to_position(coord)
		if tile.has_method("setup"):
			var color_index := posmod(coord.x + coord.y * 2, 3)
			var layer_count := 1 + posmod(coord.x + coord.y, 3)
			tile.setup(color_index, layer_count)


func _coord_to_position(coord: Vector2i) -> Vector3:
	var coord_x := float(coord.x)
	var coord_y := float(coord.y)
	var row_shift := 0.0
	if posmod(coord.y, 2) != 0:
		row_shift = column_offset
	var x := coord_x * tile_radius * 1.72 + row_shift
	var z := -coord_y * row_depth
	return Vector3(x, 0.0, z)
