extends Node3D
class_name CircleMiniGameRoot

@export_group("Scene References")
@export var camera_path: NodePath = ^"Camera3D"
@export var drifters_path: NodePath = ^"Arena/Drifters"
@export var center_core_path: NodePath = ^"Arena/CenterCore"
@export var cursor_preview_path: NodePath = ^"Effects/CursorFieldPreview"
@export var debug_label_path: NodePath = ^"UI/HUDRoot/DebugLabel"
@export var shards_label_path: NodePath = ^"UI/HUDRoot/ShardsLabel"

@export_group("Ground Plane")
@export var ground_y: float = 0.1

@export_group("Cursor Field")
@export var cursor_enabled: bool = true
@export var preview_enabled: bool = true
@export var repulsion_enabled: bool = true
@export var repulsion_radius: float = 2.2
@export var repulsion_strength: float = 0.45
@export var require_mouse_hold: bool = false
@export var mouse_button: MouseButton = MOUSE_BUTTON_LEFT

@export_group("Screen Bounds")
@export var bounds_margin: float = 0.2

@export_group("Core Absorption")
@export var core_radius: float = 1.0
@export var absorb_check_enabled: bool = true
@export var shards_per_drifter: int = 1
@export var respawn_on_absorb: bool = true

@export_group("Debug")
@export var debug_enabled: bool = true

var _camera: Camera3D
var _drifters_root: Node3D
var _center_core: Node3D
var _cursor_preview: Node3D
var _debug_label: Label
var _shards_label: Label

var _cursor_world_position: Vector3 = Vector3.ZERO
var _cursor_valid: bool = false

var _screen_min_x: float = -10.0
var _screen_max_x: float = 10.0
var _screen_min_z: float = -10.0
var _screen_max_z: float = 10.0

var shards: int = 0


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_drifters_root = get_node_or_null(drifters_path) as Node3D
	_center_core = get_node_or_null(center_core_path) as Node3D
	_cursor_preview = get_node_or_null(cursor_preview_path) as Node3D
	_debug_label = get_node_or_null(debug_label_path) as Label
	_shards_label = get_node_or_null(shards_label_path) as Label

	if _camera == null:
		push_error("CircleMiniGameRoot: Camera3D not found at path: %s" % camera_path)
		return

	if _drifters_root == null:
		push_error("CircleMiniGameRoot: Drifters root not found at path: %s" % drifters_path)

	if _center_core == null:
		push_error("CircleMiniGameRoot: CenterCore not found at path: %s" % center_core_path)

	if preview_enabled and _cursor_preview != null:
		_cursor_preview.visible = false

	_update_shards_label()
	_update_screen_bounds()
	_push_bounds_to_drifters()


func _process(delta: float) -> void:
	if cursor_enabled:
		_update_cursor_world_position()
		_update_screen_bounds()
		_push_bounds_to_drifters()
		_update_cursor_preview()

		if repulsion_enabled and _cursor_valid and _should_apply_repulsion():
			_apply_repulsion_to_drifters()

	if absorb_check_enabled:
		_check_core_absorption()

	_update_debug_text()


func _update_cursor_world_position() -> void:
	_cursor_valid = false

	if _camera == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	_cursor_world_position = _screen_to_ground(mouse_pos)

	if _cursor_world_position != Vector3.ZERO or _is_mouse_over_ground(mouse_pos):
		_cursor_world_position.y = ground_y
		_cursor_valid = true


func _update_cursor_preview() -> void:
	if _cursor_preview == null:
		return

	if not preview_enabled or not _cursor_valid:
		_cursor_preview.visible = false
		return

	_cursor_preview.visible = true
	_cursor_preview.global_position = _cursor_world_position


func _apply_repulsion_to_drifters() -> void:
	if _drifters_root == null:
		return

	for child in _drifters_root.get_children():
		if not (child is Node3D):
			continue

		if child.has_method("apply_repulsion"):
			child.apply_repulsion(_cursor_world_position, repulsion_strength, repulsion_radius)


func _should_apply_repulsion() -> bool:
	if not require_mouse_hold:
		return true

	return Input.is_mouse_button_pressed(mouse_button)


func _check_core_absorption() -> void:
	if _drifters_root == null or _center_core == null:
		return

	var core_pos_2d: Vector2 = Vector2(_center_core.global_position.x, _center_core.global_position.z)
	var to_absorb: Array[Node3D] = []

	for child in _drifters_root.get_children():
		var drifter := child as Node3D
		if drifter == null:
			continue

		var drifter_pos_2d: Vector2 = Vector2(drifter.global_position.x, drifter.global_position.z)

		var drifter_radius: float = 0.0
		if "collision_radius" in drifter:
			drifter_radius = drifter.collision_radius

		var absorb_distance: float = core_radius + drifter_radius
		if drifter_pos_2d.distance_to(core_pos_2d) <= absorb_distance:
			to_absorb.append(drifter)

	if to_absorb.is_empty():
		return

	for drifter in to_absorb:
		if is_instance_valid(drifter):
			drifter.queue_free()
			shards += shards_per_drifter

	_update_shards_label()

	if respawn_on_absorb:
		_respawn_absorbed_count(to_absorb.size())


func _respawn_absorbed_count(count: int) -> void:
	if _drifters_root == null:
		return

	if not _drifters_root.has_method("_find_valid_spawn_position"):
		return

	var existing_positions: Array[Vector3] = []
	for child in _drifters_root.get_children():
		var d := child as Node3D
		if d != null:
			existing_positions.append(d.position)

	for i in range(count):
		var pos_variant: Variant = _drifters_root._find_valid_spawn_position(existing_positions)
		if pos_variant == null:
			continue

		var pos: Vector3 = pos_variant as Vector3

		if "drifter_scene" not in _drifters_root:
			return

		var scene: PackedScene = _drifters_root.drifter_scene
		if scene == null:
			return

		var new_drifter := scene.instantiate() as Node3D
		if new_drifter == null:
			continue

		_drifters_root.add_child(new_drifter)
		new_drifter.position = pos
		existing_positions.append(pos)


func _update_shards_label() -> void:
	if _shards_label != null:
		_shards_label.text = "Shards: %d" % shards


func _update_screen_bounds() -> void:
	if _camera == null:
		return

	var viewport_rect: Rect2 = get_viewport().get_visible_rect()

	var top_left: Vector3 = _screen_to_ground(Vector2(viewport_rect.position.x, viewport_rect.position.y))
	var top_right: Vector3 = _screen_to_ground(Vector2(viewport_rect.end.x, viewport_rect.position.y))
	var bottom_left: Vector3 = _screen_to_ground(Vector2(viewport_rect.position.x, viewport_rect.end.y))
	var bottom_right: Vector3 = _screen_to_ground(Vector2(viewport_rect.end.x, viewport_rect.end.y))

	var xs := [top_left.x, top_right.x, bottom_left.x, bottom_right.x]
	var zs := [top_left.z, top_right.z, bottom_left.z, bottom_right.z]

	_screen_min_x = minf(minf(xs[0], xs[1]), minf(xs[2], xs[3])) + bounds_margin
	_screen_max_x = maxf(maxf(xs[0], xs[1]), maxf(xs[2], xs[3])) - bounds_margin
	_screen_min_z = minf(minf(zs[0], zs[1]), minf(zs[2], zs[3])) + bounds_margin
	_screen_max_z = maxf(maxf(zs[0], zs[1]), maxf(zs[2], zs[3])) - bounds_margin


func _push_bounds_to_drifters() -> void:
	if _drifters_root == null:
		return

	for child in _drifters_root.get_children():
		if child.has_method("set_screen_bounds"):
			child.set_screen_bounds(_screen_min_x, _screen_max_x, _screen_min_z, _screen_max_z)


func get_screen_spawn_bounds() -> Dictionary:
	return {
		"min_x": _screen_min_x,
		"max_x": _screen_max_x,
		"min_z": _screen_min_z,
		"max_z": _screen_max_z
	}


func _screen_to_ground(screen_pos: Vector2) -> Vector3:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_pos)

	if abs(ray_direction.y) < 0.0001:
		return Vector3.ZERO

	var t: float = (ground_y - ray_origin.y) / ray_direction.y
	if t < 0.0:
		return Vector3.ZERO

	var point: Vector3 = ray_origin + ray_direction * t
	point.y = ground_y
	return point


func _is_mouse_over_ground(screen_pos: Vector2) -> bool:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_pos)
	return abs(ray_direction.y) >= 0.0001


func _update_debug_text() -> void:
	if not debug_enabled or _debug_label == null:
		return

	if _cursor_valid:
		_debug_label.text = "Cursor: (%.2f, %.2f, %.2f)" % [
			_cursor_world_position.x,
			_cursor_world_position.y,
			_cursor_world_position.z
		]
	else:
		_debug_label.text = "Cursor: invalid"
