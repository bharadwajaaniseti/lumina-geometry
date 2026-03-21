extends Node3D
class_name CircleSpawner

@export var drifter_scene: PackedScene

@export var spawn_count: int = 8
@export var y_height: float = 0.1

@export_group("Spawn Rules")
@export var drifter_radius: float = 0.55
@export var extra_spacing: float = 0.15
@export var max_spawn_attempts_per_drifter: int = 60
@export var edge_padding: float = 0.4
@export var avoid_center: bool = true
@export var center_avoid_radius: float = 2.0

@export var clear_existing_on_ready: bool = true

var screen_min_x: float = -10.0
var screen_max_x: float = 10.0
var screen_min_z: float = -10.0
var screen_max_z: float = 10.0


func _ready() -> void:
	if drifter_scene == null:
		push_error("Drifter scene not assigned.")
		return
	call_deferred("_deferred_initial_spawn")
	if clear_existing_on_ready:
		_clear_children()

	_refresh_bounds_from_root()
	_spawn_all()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("refresh_spawn"):
		_refresh_spawn()


func _refresh_spawn() -> void:
	_refresh_bounds_from_root()
	_clear_children()
	_spawn_all()
	print("Drifters refreshed")


func _refresh_bounds_from_root() -> void:
	var root := get_parent().get_parent()
	if root == null:
		return

	if root.has_method("get_screen_spawn_bounds"):
		var bounds: Dictionary = root.get_screen_spawn_bounds()
		screen_min_x = bounds.get("min_x", screen_min_x)
		screen_max_x = bounds.get("max_x", screen_max_x)
		screen_min_z = bounds.get("min_z", screen_min_z)
		screen_max_z = bounds.get("max_z", screen_max_z)


func _spawn_all() -> void:
	var spawned_positions: Array[Vector3] = []

	for i in range(spawn_count):
		var pos_variant: Variant = _find_valid_spawn_position(spawned_positions)

		if pos_variant == null:
			push_warning("Could not find non-overlapping position for drifter %d" % i)
			continue

		var pos: Vector3 = pos_variant as Vector3

		var drifter: Node3D = drifter_scene.instantiate() as Node3D
		add_child(drifter)
		drifter.position = pos
		spawned_positions.append(pos)


func _find_valid_spawn_position(existing_positions: Array[Vector3]) -> Variant:
	for _attempt in range(max_spawn_attempts_per_drifter):
		var candidate: Vector3 = _get_random_spawn_position()

		if _is_position_valid(candidate, existing_positions):
			return candidate

	return null


func _is_position_valid(candidate: Vector3, existing_positions: Array[Vector3]) -> bool:
	var min_distance: float = (drifter_radius * 2.0) + extra_spacing
	var candidate_2d: Vector2 = Vector2(candidate.x, candidate.z)

	if avoid_center and candidate_2d.length() < center_avoid_radius:
		return false

	for pos in existing_positions:
		var existing_2d: Vector2 = Vector2(pos.x, pos.z)
		if candidate_2d.distance_to(existing_2d) < min_distance:
			return false

	return true


func _get_random_spawn_position() -> Vector3:
	var min_x: float = screen_min_x + edge_padding + drifter_radius
	var max_x: float = screen_max_x - edge_padding - drifter_radius
	var min_z: float = screen_min_z + edge_padding + drifter_radius
	var max_z: float = screen_max_z - edge_padding - drifter_radius

	var x: float = randf_range(min_x, max_x)
	var z: float = randf_range(min_z, max_z)

	return Vector3(x, y_height, z)

func _deferred_initial_spawn() -> void:
	if clear_existing_on_ready:
		_clear_children()

	_refresh_bounds_from_root()
	_spawn_all()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
