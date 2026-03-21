extends Node3D

@export var follow_speed: float = 18.0
@export var scale_in_speed: float = 14.0
@export var scale_out_speed: float = 12.0
@export var shown_scale: Vector3 = Vector3.ONE
@export var hidden_scale: Vector3 = Vector3(0.78, 0.78, 0.78)
@export var spin_speed: float = 1.8

var _target_position: Vector3 = Vector3.ZERO
var _active: bool = false


func _ready() -> void:
	scale = hidden_scale
	visible = false


func _process(delta: float) -> void:
	rotation.y += spin_speed * delta

	if _active:
		global_position = global_position.lerp(_target_position, follow_speed * delta)
		scale = scale.lerp(shown_scale, scale_in_speed * delta)
		if not visible:
			visible = true
	else:
		scale = scale.lerp(hidden_scale, scale_out_speed * delta)
		if scale.distance_to(hidden_scale) < 0.01:
			visible = false


func show_at(world_pos: Vector3) -> void:
	_target_position = world_pos
	_active = true
	if not visible:
		global_position = world_pos
		visible = true


func hide_preview() -> void:
	_active = false
