extends Node3D
class_name CircleMiniGameRoot

@export_group("Scene References")
@export var camera_path: NodePath = ^"Camera3D"
@export var drifters_path: NodePath = ^"Arena/Drifters"
@export var cursor_preview_path: NodePath = ^"Effects/CursorFieldPreview"
@export var debug_label_path: NodePath = ^"UI/HUDRoot/DebugLabel"

@export_group("Ground Plane")
@export var ground_y: float = 0.1

@export_group("Cursor Field")
@export var cursor_enabled: bool = true
@export var preview_enabled: bool = true
@export var repulsion_enabled: bool = false
@export var repulsion_radius: float = 2.5
@export var repulsion_strength: float = 6.0
@export var require_mouse_hold: bool = false
@export var mouse_button: MouseButton = MOUSE_BUTTON_LEFT

@export_group("Debug")
@export var debug_enabled: bool = true

var _camera: Camera3D
var _drifters_root: Node3D
var _cursor_preview: Node3D
var _debug_label: Label

var _cursor_world_position: Vector3 = Vector3.ZERO
var _cursor_valid: bool = false


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	_drifters_root = get_node_or_null(drifters_path) as Node3D
	_cursor_preview = get_node_or_null(cursor_preview_path) as Node3D
	_debug_label = get_node_or_null(debug_label_path) as Label

	if _camera == null:
		push_error("CircleMiniGameRoot: Camera3D not found at path: %s" % camera_path)
		return

	if preview_enabled and _cursor_preview != null:
		_cursor_preview.visible = false


func _process(delta: float) -> void:
	if not cursor_enabled:
		return

	_update_cursor_world_position()
	_update_cursor_preview()
	_update_debug_text()

	if repulsion_enabled and _cursor_valid:
		if _should_apply_repulsion():
			_apply_repulsion_to_drifters(delta)


func _update_cursor_world_position() -> void:
	_cursor_valid = false

	if _camera == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	var ray_origin: Vector3 = _camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = _camera.project_ray_normal(mouse_pos)

	if abs(ray_direction.y) < 0.0001:
		return

	var t: float = (ground_y - ray_origin.y) / ray_direction.y
	if t < 0.0:
		return

	_cursor_world_position = ray_origin + ray_direction * t
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


func _apply_repulsion_to_drifters(delta: float) -> void:
	if _drifters_root == null:
		return

	for child in _drifters_root.get_children():
		if not (child is Node3D):
			continue

		if not child.has_method("apply_repulsion"):
			continue

		child.apply_repulsion(_cursor_world_position, repulsion_strength, repulsion_radius)


func _should_apply_repulsion() -> bool:
	if not require_mouse_hold:
		return true

	return Input.is_mouse_button_pressed(mouse_button)


func _update_debug_text() -> void:
	if not debug_enabled:
		return

	if _debug_label == null:
		return

	if _cursor_valid:
		_debug_label.text = "Cursor: (%.2f, %.2f, %.2f)" % [
			_cursor_world_position.x,
			_cursor_world_position.y,
			_cursor_world_position.z
		]
	else:
		_debug_label.text = "Cursor: invalid"
