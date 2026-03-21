extends Node3D
class_name DrifterCircle

@export_group("Movement")
@export var ground_y: float = 0.1
@export var damping: float = 6.0
@export var max_speed: float = 6.0
@export var min_stop_speed: float = 0.03

@export_group("Collision")
@export var collision_radius: float = 0.55
@export var separation_iterations: int = 2
@export var collision_mask_group: StringName = &"drifters"

@export_group("Screen Bounds")
@export var use_screen_bounds: bool = true
@export var wall_bounce: float = 0.15
@export var wall_friction: float = 0.9

var velocity: Vector3 = Vector3.ZERO

var bounds_min_x: float = -10.0
var bounds_max_x: float = 10.0
var bounds_min_z: float = -10.0
var bounds_max_z: float = 10.0


func _ready() -> void:
	position.y = ground_y
	add_to_group(collision_mask_group)


func _physics_process(delta: float) -> void:
	_apply_damping(delta)

	position += velocity * delta
	position.y = ground_y

	for _i in range(separation_iterations):
		_resolve_drifter_collisions()

	if use_screen_bounds:
		_resolve_screen_bounds()

	if velocity.length() < min_stop_speed:
		velocity = Vector3.ZERO


func apply_repulsion(from_pos: Vector3, strength: float, radius: float) -> void:
	var self_flat: Vector2 = Vector2(global_position.x, global_position.z)
	var from_flat: Vector2 = Vector2(from_pos.x, from_pos.z)

	var offset: Vector2 = self_flat - from_flat
	var distance: float = offset.length()

	if distance <= 0.0001:
		var random_angle: float = randf() * TAU
		offset = Vector2(cos(random_angle), sin(random_angle))
		distance = 0.001

	if distance > radius:
		return

	var falloff: float = 1.0 - (distance / radius)
	var push_dir: Vector2 = offset.normalized()
	var push_force: Vector2 = push_dir * strength * falloff

	velocity.x += push_force.x
	velocity.z += push_force.y

	var speed: float = velocity.length()
	if speed > max_speed:
		velocity = velocity.normalized() * max_speed


func set_screen_bounds(min_x: float, max_x: float, min_z: float, max_z: float) -> void:
	bounds_min_x = min_x
	bounds_max_x = max_x
	bounds_min_z = min_z
	bounds_max_z = max_z


func _apply_damping(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, damping * delta)


func _resolve_drifter_collisions() -> void:
	var others: Array[Node] = get_tree().get_nodes_in_group(collision_mask_group)

	for node in others:
		if node == self:
			continue

		var other := node as DrifterCircle
		if other == null:
			continue

		if get_instance_id() > other.get_instance_id():
			continue

		var self_pos_2d: Vector2 = Vector2(global_position.x, global_position.z)
		var other_pos_2d: Vector2 = Vector2(other.global_position.x, other.global_position.z)

		var delta_pos: Vector2 = other_pos_2d - self_pos_2d
		var distance: float = delta_pos.length()
		var min_distance: float = collision_radius + other.collision_radius

		if distance <= 0.0001:
			var random_angle: float = randf() * TAU
			delta_pos = Vector2(cos(random_angle), sin(random_angle))
			distance = 0.001

		if distance >= min_distance:
			continue

		var normal: Vector2 = delta_pos / distance
		var overlap: float = min_distance - distance
		var correction: Vector2 = normal * (overlap * 0.5)

		global_position.x -= correction.x
		global_position.z -= correction.y
		other.global_position.x += correction.x
		other.global_position.z += correction.y

		global_position.y = ground_y
		other.global_position.y = other.ground_y

		_resolve_velocity_against_other(other, normal)


func _resolve_velocity_against_other(other: DrifterCircle, normal: Vector2) -> void:
	var self_vel_2d: Vector2 = Vector2(velocity.x, velocity.z)
	var other_vel_2d: Vector2 = Vector2(other.velocity.x, other.velocity.z)

	var relative_velocity: Vector2 = self_vel_2d - other_vel_2d
	var separating_speed: float = relative_velocity.dot(normal)

	if separating_speed >= 0.0:
		return

	var correction: Vector2 = normal * separating_speed * 0.5

	self_vel_2d -= correction
	other_vel_2d += correction

	velocity.x = self_vel_2d.x
	velocity.z = self_vel_2d.y

	other.velocity.x = other_vel_2d.x
	other.velocity.z = other_vel_2d.y


func _resolve_screen_bounds() -> void:
	var min_x: float = bounds_min_x + collision_radius
	var max_x: float = bounds_max_x - collision_radius
	var min_z: float = bounds_min_z + collision_radius
	var max_z: float = bounds_max_z - collision_radius

	# X bounds
	if global_position.x < min_x:
		global_position.x = min_x
		_bounce_x(-1.0)
	elif global_position.x > max_x:
		global_position.x = max_x
		_bounce_x(1.0)

	# Z bounds
	if global_position.z < min_z:
		global_position.z = min_z
		_bounce_z(-1.0)
	elif global_position.z > max_z:
		global_position.z = max_z
		_bounce_z(1.0)

	global_position.y = ground_y


func _bounce_x(_side: float) -> void:
	if velocity.x == 0.0:
		return

	velocity.x = -velocity.x * wall_bounce
	velocity.z *= wall_friction


func _bounce_z(_side: float) -> void:
	if velocity.z == 0.0:
		return

	velocity.z = -velocity.z * wall_bounce
	velocity.x *= wall_friction
