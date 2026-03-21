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

@export_group("Arena Bounds")
@export var use_bounds: bool = true
@export var bounds_center: Vector3 = Vector3.ZERO
@export var bounds_radius: float = 8.5
@export var wall_bounce: float = 0.15
@export var wall_friction: float = 0.9

var velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	position.y = ground_y
	add_to_group(collision_mask_group)


func _physics_process(delta: float) -> void:
	_apply_damping(delta)

	position += velocity * delta
	position.y = ground_y

	for _i in range(separation_iterations):
		_resolve_drifter_collisions()

	if use_bounds:
		_resolve_arena_bounds()

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


func _resolve_arena_bounds() -> void:
	var center_2d: Vector2 = Vector2(bounds_center.x, bounds_center.z)
	var pos_2d: Vector2 = Vector2(global_position.x, global_position.z)

	var to_pos: Vector2 = pos_2d - center_2d
	var distance: float = to_pos.length()

	var allowed_radius: float = bounds_radius - collision_radius
	if distance <= allowed_radius:
		return

	if distance <= 0.0001:
		return

	var normal: Vector2 = to_pos / distance
	var corrected_pos: Vector2 = center_2d + normal * allowed_radius

	global_position.x = corrected_pos.x
	global_position.z = corrected_pos.y
	global_position.y = ground_y

	var vel_2d: Vector2 = Vector2(velocity.x, velocity.z)
	var outward_speed: float = vel_2d.dot(normal)

	if outward_speed > 0.0:
		var normal_component: Vector2 = normal * outward_speed
		var tangent_component: Vector2 = vel_2d - normal_component

		var new_vel: Vector2 = (-normal_component * wall_bounce) + (tangent_component * wall_friction)

		velocity.x = new_vel.x
		velocity.z = new_vel.y
