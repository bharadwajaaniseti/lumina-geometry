extends Node2D

@export var arena_radius: float = 400.0
@export var repulsion_radius: float = 140.0
@export var repulsion_strength: float = 950.0

@onready var drifters_container: Node2D = $Arena/DriftersContainer
@onready var center_core: Area2D = $Arena/CenterCore
@onready var outer_ring: Sprite2D = $Arena/OuterRing
@onready var spawner: Node = $CircleSpawner
@onready var hud = $CanvasLayer/CircleMinigameHud

var shards: int = 0

func _ready() -> void:
	if spawner != null and spawner.has_method("setup"):
		spawner.setup(self)
	else:
		push_error("CircleSpawner is missing circle_spawner.gd or setup().")

	_update_outer_ring_visual()
	_update_hud()

func _update_outer_ring_visual() -> void:
	if outer_ring == null or center_core == null:
		return

	outer_ring.global_position = center_core.global_position

	var tex: Texture2D = outer_ring.texture
	if tex == null:
		return

	var texture_size: Vector2 = tex.get_size()
	if texture_size.x <= 0.0:
		return

	var target_diameter: float = arena_radius * 2.0
	var scale_factor: float = target_diameter / texture_size.x
	outer_ring.scale = Vector2(scale_factor, scale_factor)
	outer_ring.modulate.a = 0.25

func get_cursor_position() -> Vector2:
	return get_global_mouse_position()

func add_drifter(drifter: Node) -> void:
	drifters_container.add_child(drifter)

func on_drifter_absorbed(value: int) -> void:
	shards += value
	_update_hud()
	print("Shards: ", shards)

func _update_hud() -> void:
	if hud == null:
		return

	if hud.has_method("set_shards"):
		hud.set_shards(shards)
