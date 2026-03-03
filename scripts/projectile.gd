extends Area3D

const ShotPalette = preload("res://scripts/shot_palette.gd")

@export var speed: float = 24.0
@export var max_distance: float = 36.0

@onready var _visual: MeshInstance3D = $Visual

var _spawn_position: Vector3
var shot_color: int = ShotPalette.ShotColor.YELLOW
var _material: StandardMaterial3D


func _ready() -> void:
	_spawn_position = global_position
	_material = _visual.get_active_material(0).duplicate() as StandardMaterial3D
	_visual.set_surface_override_material(0, _material)
	_refresh_visuals()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += Vector3(0.0, 0.0, -speed * delta)

	if global_position.distance_to(_spawn_position) >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	var tile := body.get_parent()
	if tile != null and tile.has_method("apply_shot"):
		tile.apply_shot(shot_color)
	queue_free()


func _refresh_visuals() -> void:
	_material.albedo_color = ShotPalette.COLOR_VALUES[shot_color]
	_material.emission = ShotPalette.EMISSION_VALUES[shot_color]
