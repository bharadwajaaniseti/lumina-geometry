extends Node2D

signal pulse

## Degrees/sec when converter is fully stopped.
## Keep this at 0 if you want a true stop.
@export var stopped_speed: float = 0.0

## Degrees/sec when converter is running but only lightly active.
@export var idle_speed: float = 90.0

## Degrees/sec when converter is highly active.
@export var active_speed: float = 220.0

## Higher = faster response to speed changes.
@export var speed_lerp: float = 6.0

var drive_angle: float = 0.0
var _target_speed: float = 0.0
var _current_speed: float = 0.0
var _last_cycle_index: int = 0
var _paused: bool = false

@onready var gear_a: Node2D = $GearA
@onready var gear_b: Node2D = $GearB
@onready var gear_c: Node2D = $GearC

func _ready() -> void:
	_target_speed = stopped_speed
	_current_speed = stopped_speed
	_last_cycle_index = 0

func set_paused(value: bool) -> void:
	_paused = value
	if _paused:
		_target_speed = stopped_speed

func is_paused() -> bool:
	return _paused

func set_conversion_active(active: bool) -> void:
	if _paused:
		_target_speed = stopped_speed
		return

	_target_speed = active_speed if active else stopped_speed

func set_activity_ratio(ratio: float) -> void:
	if _paused:
		_target_speed = stopped_speed
		return

	ratio = clamp(ratio, 0.0, 1.0)

	if ratio <= 0.0:
		_target_speed = stopped_speed
	else:
		_target_speed = lerp(idle_speed, active_speed, ratio)

func _process(delta: float) -> void:
	_current_speed = lerp(_current_speed, _target_speed, clamp(speed_lerp * delta, 0.0, 1.0))

	if abs(_current_speed) < 0.001:
		_current_speed = 0.0

	drive_angle += _current_speed * delta

	gear_a.rotation_degrees = drive_angle
	gear_b.rotation_degrees = -drive_angle
	gear_c.rotation_degrees = drive_angle

	if _paused or _current_speed == 0.0:
		return

	var cycle_index: int = int(floor(drive_angle / 360.0))
	if cycle_index > _last_cycle_index:
		_last_cycle_index = cycle_index
		pulse.emit()
