extends Node3D

const ShotPalette = preload("res://scripts/shot_palette.gd")

@export var sphere_radius: float = 6.15
@export var band_rows: int = 9
@export var columns_per_row: int = 24
@export var fault_row_width: int = 2
@export var tile_scale: Vector3 = Vector3(0.78, 0.16, 0.78)
@export var latitude_extent_degrees: float = 44.0
@export var target_angle_degrees: float = 52.0

var _cells: Array[Dictionary] = []
var _cell_nodes: Dictionary = {}
var _cell_visuals: Dictionary = {}
var _cell_materials: Dictionary = {}
var _hovered_cell_id: int = -1
var _hover_mode_place: bool = false
var _grab_color: int = -1
var _held_count: int = 0
var _is_grabbing: bool = false


func _ready() -> void:
	_build_board()


func _build_board() -> void:
	for child in get_children():
		child.queue_free()

	_cells.clear()
	_cell_nodes.clear()
	_cell_visuals.clear()
	_cell_materials.clear()

	var fault_rows := _get_fault_rows()
	for row in band_rows:
		for column in columns_per_row:
			var cell_id := _get_cell_id(row, column)
			var filled := not fault_rows.has(row)
			var color_index := posmod(row * 2 + column, 3)
			var cell := {
				"id": cell_id,
				"row": row,
				"column": column,
				"filled": filled,
				"exposed": false,
				"color": color_index,
				"neighbors": _get_neighbors(row, column),
				"position": _cell_position(row, column),
				"normal": _cell_normal(row, column),
			}
			_cells.append(cell)

	for cell_index in _cells.size():
		var cell: Dictionary = _cells[cell_index]
		cell["exposed"] = _compute_exposed(cell)
		_cells[cell_index] = cell
		_spawn_cell_visual(cell)


func update_hover_from_camera(camera: Camera3D, player_radial: Vector3, mouse_position: Vector2, target_empty: bool) -> void:
	if camera == null:
		_set_hovered_cell(-1, target_empty)
		return

	var ray_origin: Vector3 = camera.project_ray_origin(mouse_position)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_position).normalized()
	var hit_point: Variant = _intersect_ray_with_sphere(ray_origin, ray_direction, sphere_radius)
	if hit_point == null:
		_set_hovered_cell(-1, target_empty)
		return

	var interaction_dot_limit: float = cos(deg_to_rad(target_angle_degrees))
	var nearest_cell_id: int = -1
	var nearest_distance: float = INF
	var hit_normal: Vector3 = (hit_point as Vector3).normalized()
	for cell in _cells:
		if target_empty:
			if cell["filled"] or not _is_placeable_empty(cell):
				continue
		elif not cell["filled"] or not cell["exposed"]:
			continue
		var cell_normal: Vector3 = cell["normal"]
		if cell_normal.dot(player_radial) < interaction_dot_limit:
			continue
		var distance_to_hit: float = cell_normal.distance_squared_to(hit_normal)
		if distance_to_hit < nearest_distance:
			nearest_distance = distance_to_hit
			nearest_cell_id = cell["id"]

	_set_hovered_cell(nearest_cell_id, target_empty)


func _compute_exposed(cell: Dictionary) -> bool:
	for neighbor_id in cell["neighbors"]:
		var neighbor := _cells[neighbor_id]
		if not neighbor["filled"]:
			return true
	return false


func _spawn_cell_visual(cell: Dictionary) -> void:
	var tile := Node3D.new()
	tile.name = "Cell_%s" % cell["id"]
	tile.position = cell["position"]
	tile.basis = _basis_from_normal(cell["normal"])

	var visual := MeshInstance3D.new()
	visual.mesh = _build_tile_mesh()
	visual.scale = tile_scale
	var material := _build_tile_material(cell["color"], cell["exposed"])
	visual.material_override = material
	tile.add_child(visual)

	add_child(tile)
	_cell_nodes[cell["id"]] = tile
	_cell_visuals[cell["id"]] = visual
	_cell_materials[cell["id"]] = material


func _build_tile_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.35
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh


func _build_tile_material(color_index: int, exposed: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = ShotPalette.COLOR_VALUES[color_index]
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = ShotPalette.EMISSION_VALUES[color_index]
	material.emission_energy_multiplier = 0.95 if exposed else 0.22
	material.roughness = 0.24 if exposed else 0.52
	return material


func _set_hovered_cell(cell_id: int, hover_mode_place: bool) -> void:
	if _hovered_cell_id == cell_id and _hover_mode_place == hover_mode_place:
		return

	_hovered_cell_id = cell_id
	_hover_mode_place = hover_mode_place
	_refresh_all_cell_visuals()


func begin_grab() -> void:
	_is_grabbing = true
	_try_add_hovered_cell_to_grab()


func update_grab() -> void:
	if not _is_grabbing:
		return
	_try_add_hovered_cell_to_grab()


func end_grab() -> void:
	_is_grabbing = false


func is_collecting_grab() -> bool:
	return _is_grabbing


func clear_grab() -> void:
	_is_grabbing = false
	_held_count = 0
	_grab_color = -1
	_refresh_all_cell_visuals()


func has_active_grab() -> bool:
	return _held_count > 0


func get_held_count() -> int:
	return _held_count


func _refresh_all_cell_visuals() -> void:
	for cell in _cells:
		_refresh_cell_visual(cell["id"])


func _refresh_cell_visual(cell_id: int) -> void:
	var cell: Dictionary = _cells[cell_id]
	var visual := _cell_visuals.get(cell_id) as MeshInstance3D
	var material := _cell_materials.get(cell_id) as StandardMaterial3D
	if visual == null or material == null:
		return
	if not cell["filled"]:
		if cell_id == _hovered_cell_id and _hover_mode_place and has_active_grab():
			visual.visible = true
			var ghost_color: Color = ShotPalette.COLOR_VALUES[_grab_color]
			var ghost_emission: Color = ShotPalette.EMISSION_VALUES[_grab_color]
			material.albedo_color = Color(ghost_color.r, ghost_color.g, ghost_color.b, 0.28)
			material.emission = ghost_emission
			material.emission_enabled = true
			material.emission_energy_multiplier = 1.6
			material.roughness = 0.08
			return
		visual.visible = false
		return

	visual.visible = true
	var base_color: Color = ShotPalette.COLOR_VALUES[cell["color"]]
	var emission_color: Color = ShotPalette.EMISSION_VALUES[cell["color"]]
	material.albedo_color = base_color
	material.emission = emission_color
	material.emission_enabled = true
	material.emission_energy_multiplier = 0.95 if cell["exposed"] else 0.22
	material.roughness = 0.24 if cell["exposed"] else 0.52
	material.albedo_color.a = 1.0
	if cell_id == _hovered_cell_id and not _hover_mode_place:
		material.emission_energy_multiplier = 1.8
		material.roughness = 0.12
		material.albedo_color = base_color.lightened(0.2)


func _intersect_ray_with_sphere(ray_origin: Vector3, ray_direction: Vector3, radius: float) -> Variant:
	var a: float = ray_direction.dot(ray_direction)
	var b: float = 2.0 * ray_origin.dot(ray_direction)
	var c: float = ray_origin.dot(ray_origin) - radius * radius
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return null

	var sqrt_discriminant: float = sqrt(discriminant)
	var near_t: float = (-b - sqrt_discriminant) / (2.0 * a)
	var far_t: float = (-b + sqrt_discriminant) / (2.0 * a)
	var hit_t: float = near_t if near_t >= 0.0 else far_t
	if hit_t < 0.0:
		return null

	return ray_origin + ray_direction * hit_t


func _try_add_hovered_cell_to_grab() -> void:
	if _hovered_cell_id < 0:
		return

	var cell: Dictionary = _cells[_hovered_cell_id]
	if not cell["filled"] or not cell["exposed"]:
		return

	if _grab_color < 0:
		_grab_color = cell["color"]
	elif cell["color"] != _grab_color:
		return

	cell["filled"] = false
	cell["exposed"] = false
	_cells[_hovered_cell_id] = cell
	_held_count += 1
	_recompute_exposure()
	_refresh_all_cell_visuals()


func place_held_tiles() -> void:
	if _held_count <= 0 or _grab_color < 0 or _hovered_cell_id < 0:
		return
	var hovered_cell: Dictionary = _cells[_hovered_cell_id]
	if hovered_cell["filled"] or not _is_placeable_empty(hovered_cell):
		return

	var placement_cells: Array[int] = _collect_place_cells(_hovered_cell_id, _held_count)
	if placement_cells.size() < _held_count:
		return

	for cell_id in placement_cells:
		var cell: Dictionary = _cells[cell_id]
		cell["filled"] = true
		cell["color"] = _grab_color
		_cells[cell_id] = cell

	_held_count = 0
	_grab_color = -1
	_hover_mode_place = false
	_resolve_pops_from_cells(placement_cells)
	_recompute_exposure()
	_refresh_all_cell_visuals()


func _recompute_exposure() -> void:
	for cell_index in _cells.size():
		var cell: Dictionary = _cells[cell_index]
		if cell["filled"]:
			cell["exposed"] = _compute_exposed(cell)
		else:
			cell["exposed"] = false
		_cells[cell_index] = cell


func _resolve_pops_from_cells(seed_cells: Array[int]) -> void:
	var popped_any := true
	while popped_any:
		popped_any = false
		var to_pop: Dictionary = {}
		var next_seed_dict: Dictionary = {}
		for seed_cell_id: int in seed_cells:
			if seed_cell_id < 0 or seed_cell_id >= _cells.size():
				continue
			var cell: Dictionary = _cells[seed_cell_id]
			if not cell["filled"]:
				continue
			var group: Array[int] = _collect_connected_group(seed_cell_id, cell["color"])
			if group.size() >= 3:
				popped_any = true
				for group_cell_id: int in group:
					to_pop[group_cell_id] = true
		for group_cell_id_variant in to_pop.keys():
			var group_cell_id: int = int(group_cell_id_variant)
			var cell: Dictionary = _cells[group_cell_id]
			cell["filled"] = false
			cell["exposed"] = false
			_cells[group_cell_id] = cell
			for neighbor_id_variant in cell["neighbors"]:
				var neighbor_id: int = int(neighbor_id_variant)
				next_seed_dict[neighbor_id] = true
		if popped_any:
			_recompute_exposure()
			var next_seed_cells: Array[int] = []
			for neighbor_id_variant in next_seed_dict.keys():
				next_seed_cells.append(int(neighbor_id_variant))
			seed_cells = next_seed_cells


func _collect_connected_group(start_cell_id: int, color_index: int) -> Array[int]:
	var stack: Array[int] = [start_cell_id]
	var group: Array[int] = []
	var visited: Dictionary = {}
	while not stack.is_empty():
		var cell_id: int = int(stack.pop_back())
		if visited.has(cell_id):
			continue
		visited[cell_id] = true
		var cell: Dictionary = _cells[cell_id]
		if not cell["filled"] or cell["color"] != color_index:
			continue
		group.append(cell_id)
		for neighbor_id_variant in cell["neighbors"]:
			var neighbor_id: int = int(neighbor_id_variant)
			if not visited.has(neighbor_id):
				stack.append(neighbor_id)
	return group


func _collect_place_cells(start_cell_id: int, count: int) -> Array[int]:
	var queue: Array[int] = [start_cell_id]
	var seen: Dictionary = {}
	var result: Array[int] = []
	while not queue.is_empty() and result.size() < count:
		var cell_id: int = int(queue.pop_front())
		if seen.has(cell_id):
			continue
		seen[cell_id] = true
		var cell: Dictionary = _cells[cell_id]
		if cell["filled"]:
			continue
		result.append(cell_id)
		var neighbor_ids: Array[int] = cell["neighbors"].duplicate()
		neighbor_ids.sort()
		for neighbor_id: int in neighbor_ids:
			if not seen.has(neighbor_id):
				queue.append(neighbor_id)
	return result


func _is_placeable_empty(cell: Dictionary) -> bool:
	if cell["filled"]:
		return false
	for neighbor_id_variant in cell["neighbors"]:
		var neighbor_id: int = int(neighbor_id_variant)
		var neighbor: Dictionary = _cells[neighbor_id]
		if neighbor["filled"]:
			return true
	return false


func _basis_from_normal(normal: Vector3) -> Basis:
	var reference_forward := Vector3.FORWARD
	if absf(normal.dot(reference_forward)) > 0.98:
		reference_forward = Vector3.RIGHT
	var tangent_right := reference_forward.cross(normal).normalized()
	var tangent_forward := normal.cross(tangent_right).normalized()
	return Basis(tangent_right, normal, tangent_forward).orthonormalized()


func _get_fault_rows() -> Array[int]:
	var rows: Array[int] = []
	var start_row := int(floor((band_rows - fault_row_width) / 2.0))
	for offset in fault_row_width:
		rows.append(start_row + offset)
	return rows


func _get_neighbors(row: int, column: int) -> Array[int]:
	var neighbors: Array[int] = []
	var left_column := posmod(column - 1, columns_per_row)
	var right_column := posmod(column + 1, columns_per_row)
	neighbors.append(_get_cell_id(row, left_column))
	neighbors.append(_get_cell_id(row, right_column))

	var upper_row := row - 1
	var lower_row := row + 1
	var offset := 0 if row % 2 == 0 else 1

	if upper_row >= 0:
		neighbors.append(_get_cell_id(upper_row, column))
		neighbors.append(_get_cell_id(upper_row, posmod(column - 1 + offset, columns_per_row)))
	if lower_row < band_rows:
		neighbors.append(_get_cell_id(lower_row, column))
		neighbors.append(_get_cell_id(lower_row, posmod(column - 1 + offset, columns_per_row)))

	return neighbors


func _cell_position(row: int, column: int) -> Vector3:
	return _cell_normal(row, column) * sphere_radius


func _cell_normal(row: int, column: int) -> Vector3:
	var latitude_t: float = (float(row) + 0.5) / float(band_rows)
	var row_offset: float = 0.5 if row % 2 != 0 else 0.0
	var longitude_t: float = (float(column) + 0.5 + row_offset) / float(columns_per_row)
	var latitude_extent_radians: float = deg_to_rad(latitude_extent_degrees)
	var latitude: float = lerpf(-latitude_extent_radians, latitude_extent_radians, latitude_t)
	var longitude: float = longitude_t * TAU

	var x: float = cos(latitude) * sin(longitude)
	var y: float = sin(latitude)
	var z: float = cos(latitude) * cos(longitude)
	return Vector3(x, y, z).normalized()


func _get_cell_id(row: int, column: int) -> int:
	return row * columns_per_row + column
