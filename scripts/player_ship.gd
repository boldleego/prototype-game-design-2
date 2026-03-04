extends Node3D

@export var orbit_radius: float = 12.0
@export var orbit_move_speed: float = 10.0
@export var frame_roll_speed: float = 2.1
@export var camera_path: NodePath
@export var sphere_board_path: NodePath
@export var camera_distance: float = 4.8
@export var camera_height: float = 1.8
@export var camera_lerp_speed: float = 6.0

@onready var _body: MeshInstance3D = $Body
@onready var _nose: MeshInstance3D = $Nose

var _radial: Vector3 = Vector3(0.0, 0.18, 1.0).normalized()
var _frame_roll: float = 0.0
var _camera: Camera3D
var _sphere_board: Node
var _was_grab_pressed: bool = false


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_sphere_board = get_node_or_null(sphere_board_path)
	_radial = global_position.normalized()
	if _radial.is_zero_approx():
		_radial = Vector3(0.0, 0.18, 1.0).normalized()
	_apply_ship_material()
	_update_orbit_transform(0.0, true)


func _process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var roll_input := Input.get_axis("roll_left", "roll_right")
	_frame_roll += roll_input * frame_roll_speed * delta

	var movement_input := Vector2(input_vector.x, -input_vector.y)
	if movement_input.length_squared() > 0.0:
		var tangent_basis: Array[Vector3] = _get_tangent_basis()
		var rotated_right: Vector3 = tangent_basis[0].rotated(_radial, _frame_roll)
		var rotated_up: Vector3 = tangent_basis[1].rotated(_radial, _frame_roll)
		var tangent_move: Vector3 = (rotated_right * movement_input.x) + (rotated_up * movement_input.y)
		_radial = (_radial + tangent_move * (orbit_move_speed / orbit_radius) * delta).normalized()
	_update_orbit_transform(delta, false)
	_update_mouse_hover()
	_update_grab_input()


func _update_orbit_transform(delta: float, snap_camera: bool) -> void:
	global_position = _radial * orbit_radius

	var tangent_basis: Array[Vector3] = _get_tangent_basis()
	var rotated_right: Vector3 = tangent_basis[0].rotated(_radial, _frame_roll)
	var rotated_up: Vector3 = tangent_basis[1].rotated(_radial, _frame_roll)
	global_basis = Basis(rotated_right, _radial, -rotated_up).orthonormalized()

	if _camera == null:
		return

	var desired_camera_position: Vector3 = global_position + _radial * camera_distance + Vector3.UP * camera_height
	if snap_camera:
		_camera.global_position = desired_camera_position
	else:
		var weight: float = clampf(delta * camera_lerp_speed, 0.0, 1.0)
		_camera.global_position = _camera.global_position.lerp(desired_camera_position, weight)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _update_mouse_hover() -> void:
	if _sphere_board == null or _camera == null:
		return
	if _sphere_board.has_method("update_hover_from_camera"):
		var target_empty := false
		if _sphere_board.has_method("has_active_grab") and _sphere_board.has_method("is_collecting_grab"):
			target_empty = _sphere_board.has_active_grab() and not _sphere_board.is_collecting_grab()
		_sphere_board.update_hover_from_camera(_camera, _radial, get_viewport().get_mouse_position(), target_empty)


func _update_grab_input() -> void:
	if _sphere_board == null:
		return

	var is_grab_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if is_grab_pressed and not _was_grab_pressed:
		if _sphere_board.has_method("has_active_grab") and _sphere_board.has_method("is_collecting_grab") and _sphere_board.has_active_grab() and not _sphere_board.is_collecting_grab():
			if _sphere_board.has_method("place_held_tiles"):
				_sphere_board.place_held_tiles()
		elif _sphere_board.has_method("begin_grab"):
			_sphere_board.begin_grab()
	elif is_grab_pressed and _was_grab_pressed:
		if _sphere_board.has_method("is_collecting_grab") and _sphere_board.is_collecting_grab() and _sphere_board.has_method("update_grab"):
			_sphere_board.update_grab()
	elif not is_grab_pressed and _was_grab_pressed:
		if _sphere_board.has_method("is_collecting_grab") and _sphere_board.is_collecting_grab() and _sphere_board.has_method("end_grab"):
			_sphere_board.end_grab()

	_was_grab_pressed = is_grab_pressed


func _get_tangent_basis() -> Array[Vector3]:
	var reference_up: Vector3 = Vector3.UP
	if absf(_radial.dot(reference_up)) > 0.98:
		reference_up = Vector3.RIGHT

	var tangent_up: Vector3 = (reference_up - _radial * _radial.dot(reference_up)).normalized()
	var tangent_right: Vector3 = tangent_up.cross(_radial).normalized()
	return [tangent_right, tangent_up]


func _apply_ship_material() -> void:
	var body_material := _body.get_active_material(0).duplicate() as StandardMaterial3D
	body_material.albedo_color = Color(0.258824, 0.85098, 0.878431, 1)
	body_material.emission_enabled = true
	body_material.emission = Color(0.16, 0.62, 0.82, 1)
	body_material.emission_energy_multiplier = 0.55
	_body.set_surface_override_material(0, body_material)

	var nose_material := _nose.get_active_material(0).duplicate() as StandardMaterial3D
	nose_material.albedo_color = Color(0.984314, 0.760784, 0.294118, 1)
	nose_material.emission_enabled = true
	nose_material.emission = Color(1, 0.682353, 0.172549, 1)
	nose_material.emission_energy_multiplier = 0.8
	_nose.set_surface_override_material(0, nose_material)
