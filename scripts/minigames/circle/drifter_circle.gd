extends Area2D

@export var jump_interval_min: float = 0.45
@export var jump_interval_max: float = 0.95
@export var jump_force_min: float = 70.0
@export var jump_force_max: float = 140.0
@export var friction: float = 7.0
@export var max_speed: float = 220.0
@export var value_shards: int = 1

var velocity: Vector2 = Vector2.ZERO
var game: Node = null
var jump_timer: float = 0.0

func _ready() -> void:
	_reset_jump_timer()

func setup(_game: Node) -> void:
	game = _game

func _process(delta: float) -> void:
	if game != null:
		_apply_repulsion(delta)

	jump_timer -= delta
	if jump_timer <= 0.0:
		_do_jump()
		_reset_jump_timer()

	position += velocity * delta

	# Stronger slowdown so movement feels like short hops, not float.
	velocity = velocity.move_toward(Vector2.ZERO, friction * 100.0 * delta)

	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

func _reset_jump_timer() -> void:
	jump_timer = randf_range(jump_interval_min, jump_interval_max)

func _do_jump() -> void:
	var dir := Vector2.from_angle(randf() * TAU)
	var force := randf_range(jump_force_min, jump_force_max)
	velocity += dir * force

func _apply_repulsion(delta: float) -> void:
	var cursor_pos: Vector2 = game.get_cursor_position()
	var dir: Vector2 = global_position - cursor_pos
	var dist: float = dir.length()

	if dist <= 0.001:
		return

	if dist < game.repulsion_radius:
		var strength_ratio: float = 1.0 - (dist / game.repulsion_radius)
		var force: Vector2 = dir.normalized() * strength_ratio * game.repulsion_strength
		velocity += force * delta

func on_absorbed() -> void:
	if game != null and game.has_method("on_drifter_absorbed"):
		game.on_drifter_absorbed(value_shards)
	queue_free()
