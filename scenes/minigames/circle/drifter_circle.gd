extends Node3D
class_name DrifterCircle

@export_group("Node References")
## Child visual node that gets lifted / tilted during the hop.
## Expected path: Body
@export var body_path: NodePath = ^"Body"

@export_group("Collision")
## Radius used for targeting, landing separation, and core absorption checks.
@export_range(0.01, 10.0, 0.01) var collision_radius: float = 0.55
## Group name used to find other drifters for landing overlap resolution.
@export var collision_mask_group: StringName = &"drifters"

@export_group("Ground")
## Ground height the drifter root stays on. Keep this matched with the game root.
@export var ground_y: float = 0.1

@export_group("Hop Behaviour")
## Per-drifter weight. Heavier drifters travel less for the same click power.
## 1.0 = normal, below 1.0 = lighter, above 1.0 = heavier.
@export_range(0.1, 10.0, 0.05) var drifter_weight: float = 1.0
## Base distance this drifter will travel even with low click power.
@export_range(0.0, 20.0, 0.01) var hop_base_distance: float = 1.2
## Extra distance gained from click power, before weight is applied.
@export_range(0.0, 20.0, 0.01) var hop_power_multiplier: float = 0.8
## Maximum final hop distance allowed after all calculations.
@export_range(0.0, 50.0, 0.01) var max_hop_distance: float = 2.5
## Total time for one full hop from takeoff to landing.
@export_range(0.01, 5.0, 0.01) var hop_duration: float = 0.22
## Visual arc height of the hop.
@export_range(0.0, 10.0, 0.01) var hop_height: float = 0.45
## Visual tilt during flight. Higher values feel more exaggerated.
@export_range(0.0, 90.0, 0.1) var hop_tilt_degrees: float = 12.0
## Delay before this drifter can be triggered again.
@export_range(0.0, 5.0, 0.01) var hop_cooldown: float = 0.08

@export_group("Screen Bounds")
## If true, landing positions are clamped to the current visible screen bounds.
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


## Triggers one discrete hop away from the click point.
## radius controls whether this drifter is affected at all.
## hop_power controls how much extra distance is added.
func trigger_hop_away_from(from_pos: Vector3, radius: float, hop_power: float = 1.0) -> void:
	if _is_hopping:
		return

	if _cooldown_left > 0.0:
		return

	var self_flat: Vector2 = Vector2(global_position.x, global_position.z)
	var from_flat: Vector2 = Vector2(from_pos.x, from_pos.z)

	var offset: Vector2 = self_flat - from_flat
	var distance: float = offset.length()

	if distance > radius:
		return

	var dir_2d: Vector2
	if distance <= 0.0001:
		var angle := randf() * TAU
		dir_2d = Vector2(cos(angle), sin(angle))
	else:
		dir_2d = offset.normalized()

	var safe_weight: float = maxf(drifter_weight, 0.1)
	var final_hop_distance: float = hop_base_distance + (hop_power * hop_power_multiplier / safe_weight)
	final_hop_distance = minf(final_hop_distance, max_hop_distance)

	var target: Vector3 = global_position + Vector3(dir_2d.x, 0.0, dir_2d.y) * final_hop_distance
	target.y = ground_y

	if use_screen_bounds:
		target = _clamp_to_screen_bounds(target)

	target = _resolve_landing_overlap(target)

	_hop_start = global_position
	_hop_end = target
	_hop_dir = (_hop_end - _hop_start).normalized()

	_hop_time = 0.0
	_is_hopping = true
	_cooldown_left = hop_cooldown


## Called by the root controller so each drifter knows the current visible world bounds.
func set_screen_bounds(min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	bounds_min_x = min_x
	bounds_max_x = max_x
	bounds_min_z = min_z
	bounds_max_z = max_z


func is_hopping() -> bool:
	return _is_hopping


func _update_hop(delta: float) -> void:
	_hop_time += delta
	var t: float = clampf(_hop_time / hop_duration, 0.0, 1.0)

	var horizontal: Vector3 = _hop_start.lerp(_hop_end, t)
	var arc: float = sin(t * PI) * hop_height

	global_position = horizontal
	global_position.y = ground_y

	if _body != null:
		_body.position.y = arc

		var tilt_strength: float = sin(t * PI)
		_body.rotation.x = deg_to_rad(-_hop_dir.z * hop_tilt_degrees * tilt_strength)
		_body.rotation.z = deg_to_rad(_hop_dir.x * hop_tilt_degrees * tilt_strength)

		var stretch: float = 1.0 + 0.06 * tilt_strength
		var squash: float = 1.0 - 0.06 * tilt_strength
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
	var result: Vector3 = target

	for node in others:
		if node == self:
			continue

		var other := node as DrifterCircle
		if other == null:
			continue

		var my_2d: Vector2 = Vector2(result.x, result.z)
		var other_2d: Vector2 = Vector2(other.global_position.x, other.global_position.z)

		var min_dist: float = collision_radius + other.collision_radius
		var dist: float = my_2d.distance_to(other_2d)

		if dist < min_dist and dist > 0.0001:
			var push_dir: Vector2 = (my_2d - other_2d).normalized()
			var corrected: Vector2 = other_2d + push_dir * min_dist
			result.x = corrected.x
			result.z = corrected.y
		elif dist <= 0.0001:
			result.x += collision_radius * 0.5

	if use_screen_bounds:
		result = _clamp_to_screen_bounds(result)

	return result

## Returns predicted hop data without actually moving the drifter.
## Useful for previews, targeting, and landing markers.
func get_predicted_hop(from_pos: Vector3, radius: float, hop_power: float = 1.0) -> Dictionary:
	var result := {
		"valid": false,
		"start": global_position,
		"end": global_position,
		"direction": Vector3.ZERO,
		"distance": 0.0,
		"height": hop_height,
		"duration": hop_duration
	}

	if _is_hopping:
		return result

	if _cooldown_left > 0.0:
		return result

	var self_flat: Vector2 = Vector2(global_position.x, global_position.z)
	var from_flat: Vector2 = Vector2(from_pos.x, from_pos.z)

	var offset: Vector2 = self_flat - from_flat
	var distance_to_click: float = offset.length()

	if distance_to_click > radius:
		return result

	var dir_2d: Vector2
	if distance_to_click <= 0.0001:
		var angle := randf() * TAU
		dir_2d = Vector2(cos(angle), sin(angle))
	else:
		dir_2d = offset.normalized()

	var safe_weight: float = maxf(drifter_weight, 0.1)
	var final_hop_distance: float = hop_base_distance + (hop_power * hop_power_multiplier / safe_weight)
	final_hop_distance = minf(final_hop_distance, max_hop_distance)

	var target: Vector3 = global_position + Vector3(dir_2d.x, 0.0, dir_2d.y) * final_hop_distance
	target.y = ground_y

	if use_screen_bounds:
		target = _clamp_to_screen_bounds(target)

	target = _resolve_landing_overlap(target)

	var dir_3d := (target - global_position).normalized()

	result["valid"] = true
	result["start"] = global_position
	result["end"] = target
	result["direction"] = dir_3d
	result["distance"] = global_position.distance_to(target)
	result["height"] = hop_height
	result["duration"] = hop_duration

	return result
