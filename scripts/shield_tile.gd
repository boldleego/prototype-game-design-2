extends Node3D

const ShotPalette = preload("res://scripts/shot_palette.gd")

@export_range(1, 3, 1) var max_layers: int = 3

@onready var _visual: MeshInstance3D = $Visual
@onready var _hitbox: StaticBody3D = $Hitbox
@onready var _collision_shape: CollisionShape3D = $Hitbox/CollisionShape3D

var tile_color: int = ShotPalette.ShotColor.YELLOW
var layers: int = max_layers
var _material: StandardMaterial3D


func _ready() -> void:
	_material = _visual.get_active_material(0).duplicate() as StandardMaterial3D
	_visual.set_surface_override_material(0, _material)
	_refresh_visuals()


func setup(color_value: int, layer_count: int) -> void:
	tile_color = color_value
	layers = clampi(layer_count, 1, max_layers)
	if is_node_ready():
		_refresh_visuals()


func apply_shot(shot_color: int) -> void:
	if layers <= 0:
		return

	var damage := 1
	if shot_color == tile_color:
		damage = 3
	else:
		tile_color = shot_color

	layers = maxi(layers - damage, 0)
	_refresh_visuals()


func _refresh_visuals() -> void:
	var color_value: Color = ShotPalette.COLOR_VALUES.get(tile_color, Color.WHITE)
	var emission_value: Color = ShotPalette.EMISSION_VALUES.get(tile_color, color_value)

	_material.albedo_color = color_value
	_material.emission = emission_value
	_material.emission_energy_multiplier = 0.35 + float(layers) * 0.25

	if layers <= 0:
		_visual.visible = false
		_hitbox.process_mode = Node.PROCESS_MODE_DISABLED
		_collision_shape.disabled = true
		return

	_visual.visible = true
	_hitbox.process_mode = Node.PROCESS_MODE_INHERIT
	_collision_shape.disabled = false
	_visual.scale = Vector3.ONE * (0.75 + float(layers) * 0.1)
	_material.albedo_color.a = 0.45 + float(layers) * 0.16
