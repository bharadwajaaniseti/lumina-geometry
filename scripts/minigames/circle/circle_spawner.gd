extends Node

@export var drifter_scene: PackedScene
@export var spawn_interval: float = 1.0
@export var max_drifters: int = 10
@export var spawn_radius_offset: float = 0.0

var timer: float = 0.0
var game: Node = null

func setup(_game: Node) -> void:
	game = _game

func _process(delta: float) -> void:
	if game == null:
		return

	timer += delta
	if timer >= spawn_interval:
		timer = 0.0
		_try_spawn()

func _try_spawn() -> void:
	if drifter_scene == null:
		return

	if game.drifters_container.get_child_count() >= max_drifters:
		return

	var drifter = drifter_scene.instantiate()

	var angle: float = randf() * TAU
	var center: Vector2 = game.center_core.global_position

	# Spawn slightly inside the ring for better feel.
	var radius: float = (game.arena_radius + spawn_radius_offset) * randf_range(0.85, 1.0)
	var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius

	drifter.global_position = pos

	if drifter.has_method("setup"):
		drifter.setup(game)

	game.add_drifter(drifter)
