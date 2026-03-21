extends Node3D
class_name CircleSpawner

@export var drifter_scene: PackedScene

@export var spawn_count: int = 8
@export var spawn_radius_min: float = 3.0
@export var spawn_radius_max: float = 8.0
@export var y_height: float = 0.1

@export var drifter_radius: float = 0.55
@export var extra_spacing: float = 0.15
@export var max_spawn_attempts_per_drifter: int = 50

@export var clear_existing_on_ready: bool = true


func _ready() -> void:
	if drifter_scene == null:
		push_error("Drifter scene not assigned.")
		return

	if clear_existing_on_ready:
		_clear_children()

	_spawn_all()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("refresh_spawn"):
		_refresh_spawn()


func _refresh_spawn() -> void:
	_clear_children()
	_spawn_all()
	print("Drifters refreshed")


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
	for attempt in range(max_spawn_attempts_per_drifter):
		var candidate := _get_random_spawn_position()

		if _is_position_valid(candidate, existing_positions):
			return candidate

	return null


func _is_position_valid(candidate: Vector3, existing_positions: Array[Vector3]) -> bool:
	var min_distance := (drifter_radius * 2.0) + extra_spacing

	for pos in existing_positions:
		var a := Vector2(candidate.x, candidate.z)
		var b := Vector2(pos.x, pos.z)

		if a.distance_to(b) < min_distance:
			return false

	return true


func _get_random_spawn_position() -> Vector3:
	var angle := randf() * TAU
	var radius := randf_range(spawn_radius_min, spawn_radius_max)

	var x := cos(angle) * radius
	var z := sin(angle) * radius

	return Vector3(x, y_height, z)


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
