extends Node3D
class_name DrifterCircle

@export_group("Node References")
@export var body_path: NodePath = ^"Body"

@export_group("Collision")
@export var collision_radius: float = 0.55
@export var collision_mask_group: StringName = &"drifters"

@export_group("Ground")
@export var ground_y: float = 0.1

@export_group("Hop")
@export var hop_distance: float = 1.8
@export var hop_duration: float = 0.22
@export var hop_height: float = 0.45
@export var hop_tilt_degrees: float = 12.0
@export var hop_cooldown: float = 0.08

@export_group("Screen Bounds")
@export var use_screen_bounds: bool = true

var bounds_min_x: float = -10.0
var bounds_max_x: float = 10.0
var bounds_min_z: float = -10.0
var bounds_max_z: float = 10.0

var _body: Node3D
var _is_hopping: bool = false
var _hop_time: float = 0.0
var _cooldown_left: float = 0.0

var _hop_start: Vector3 = Vector3.ZERO
var _hop_end: Vector3 = Vector3.ZERO
var _hop_dir: Vector3 = Vector3.ZERO


func _ready() -> void:
	position.y = ground_y
	add_to_group(collision_mask_group)

	_body = get_node_or_null(body_path) as Node3D
	if _body == null:
		push_warning("DrifterCircle: Body node not found at path: %s" % body_path)


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta

	if _is_hopping:
		_update_hop(delta)
	else:
		_reset_body_visual()


func trigger_hop_away_from(from_pos: Vector3, radius: float) -> void:
	if _is_hopping:
		return

	if _cooldown_left > 0.0:
		return

	var self_flat := Vector2(global_position.x, global_position.z)
	var from_flat := Vector2(from_pos.x, from_pos.z)

	var offset := self_flat - from_flat
	var distance := offset.length()

	if distance > radius:
		return

	var dir_2d: Vector2
	if distance <= 0.0001:
		var angle := randf() * TAU
		dir_2d = Vector2(cos(angle), sin(angle))
	else:
		dir_2d = offset.normalized()

	var target := global_position + Vector3(dir_2d.x, 0.0, dir_2d.y) * hop_distance
	target.y = ground_y

	if use_screen_bounds:
		target = _clamp_to_screen_bounds(target)

	# Optional: avoid landing inside another drifter
	target = _resolve_landing_overlap(target)

	_hop_start = global_position
	_hop_end = target
	_hop_dir = (_hop_end - _hop_start).normalized()

	_hop_time = 0.0
	_is_hopping = true
	_cooldown_left = hop_cooldown


func set_screen_bounds(min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	bounds_min_x = min_x
	bounds_max_x = max_x
	bounds_min_z = min_z
	bounds_max_z = max_z


func is_hopping() -> bool:
	return _is_hopping


func _update_hop(delta: float) -> void:
	_hop_time += delta
	var t := clampf(_hop_time / hop_duration, 0.0, 1.0)

	var horizontal := _hop_start.lerp(_hop_end, t)
	var arc := sin(t * PI) * hop_height

	global_position = horizontal
	global_position.y = ground_y

	if _body != null:
		_body.position.y = arc

		var tilt_strength := sin(t * PI)
		_body.rotation.x = deg_to_rad(-_hop_dir.z * hop_tilt_degrees * tilt_strength)
		_body.rotation.z = deg_to_rad(_hop_dir.x * hop_tilt_degrees * tilt_strength)

		var stretch := 1.0 + 0.06 * tilt_strength
		var squash := 1.0 - 0.06 * tilt_strength
		_body.scale = Vector3(squash, stretch, squash)

	if t >= 1.0:
		global_position = _hop_end
		global_position.y = ground_y
		_is_hopping = false
		_reset_body_visual()


func _reset_body_visual() -> void:
	if _body == null:
		return

	_body.position.y = 0.0
	_body.rotation = Vector3.ZERO
	_body.scale = Vector3.ONE


func _clamp_to_screen_bounds(target: Vector3) -> Vector3:
	target.x = clampf(target.x, bounds_min_x + collision_radius, bounds_max_x - collision_radius)
	target.z = clampf(target.z, bounds_min_z + collision_radius, bounds_max_z - collision_radius)
	target.y = ground_y
	return target


func _resolve_landing_overlap(target: Vector3) -> Vector3:
	var others: Array[Node] = get_tree().get_nodes_in_group(collision_mask_group)
	var result := target

	for node in others:
		if node == self:
			continue

		var other := node as DrifterCircle
		if other == null:
			continue

		var my_2d := Vector2(result.x, result.z)
		var other_2d := Vector2(other.global_position.x, other.global_position.z)

		var min_dist := collision_radius + other.collision_radius
		var dist := my_2d.distance_to(other_2d)

		if dist < min_dist and dist > 0.0001:
			var push_dir := (my_2d - other_2d).normalized()
			var corrected := other_2d + push_dir * min_dist
			result.x = corrected.x
			result.z = corrected.y
		elif dist <= 0.0001:
			result.x += collision_radius * 0.5

	if use_screen_bounds:
		result = _clamp_to_screen_bounds(result)

	return result
