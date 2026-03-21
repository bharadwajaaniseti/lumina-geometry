extends Node3D

## How quickly the target preview follows the chosen drifter.
@export_range(0.0, 100.0, 0.1) var follow_speed: float = 18.0
## Speed used when growing the marker in.
@export_range(0.0, 100.0, 0.1) var scale_in_speed: float = 14.0
## Speed used when shrinking the marker out.
@export_range(0.0, 100.0, 0.1) var scale_out_speed: float = 12.0
## Fully visible scale for the target marker.
@export var shown_scale: Vector3 = Vector3.ONE
## Hidden scale for the target marker. Lower values make it collapse more when not active.
@export var hidden_scale: Vector3 = Vector3(0.78, 0.78, 0.78)
## Optional slow spin to make the selected marker feel alive.
@export_range(0.0, 20.0, 0.01) var spin_speed: float = 1.8

var _target_position: Vector3 = Vector3.ZERO
var _active: bool = false


func _ready() -> void:
	scale = hidden_scale
	visible = false


func _process(delta: float) -> void:
	rotation.y += spin_speed * delta

	if _active:
		global_position = global_position.lerp(_target_position, clampf(follow_speed * delta, 0.0, 1.0))
		scale = scale.lerp(shown_scale, clampf(scale_in_speed * delta, 0.0, 1.0))
		if not visible:
			visible = true
	else:
		scale = scale.lerp(hidden_scale, clampf(scale_out_speed * delta, 0.0, 1.0))
		if scale.distance_to(hidden_scale) < 0.01:
			visible = false


## Show the target preview at the given world position.
func show_at(world_pos: Vector3) -> void:
	_target_position = world_pos
	_active = true
	if not visible:
		global_position = world_pos
		visible = true


## Hide the target preview smoothly.
func hide_preview() -> void:
	_active = false
