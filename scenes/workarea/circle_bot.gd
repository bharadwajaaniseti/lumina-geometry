extends Node2D

enum Facing {
	DOWN,
	UP,
	SIDE
}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_label: Label = $StateLabel

var speed: float = 200.0
var is_kicking: bool = false

var move_input: Vector2 = Vector2.ZERO
var facing: int = Facing.DOWN
var facing_left: bool = false


func _ready() -> void:
	_play_idle()


func _process(delta: float) -> void:
	if is_kicking:
		return

	move_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if move_input != Vector2.ZERO:
		move_input = move_input.normalized()
		position += move_input * speed * delta
		_update_facing_from_input(move_input)
		_play_walk()
	else:
		_play_idle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not is_kicking:
		_play_kick()


func _update_facing_from_input(input_dir: Vector2) -> void:
	# Decide whether movement is mostly horizontal or vertical
	if abs(input_dir.x) > abs(input_dir.y):
		facing = Facing.SIDE
		facing_left = input_dir.x < 0.0
	else:
		if input_dir.y < 0.0:
			facing = Facing.UP
		else:
			facing = Facing.DOWN


func _play_idle() -> void:
	match facing:
		Facing.DOWN:
			_set_anim("idle_down", false)
		Facing.UP:
			_set_anim("idle_up", false)
		Facing.SIDE:
			_set_anim("idle_side", facing_left)


func _play_walk() -> void:
	match facing:
		Facing.DOWN:
			_set_anim("walk_down", false)
		Facing.UP:
			_set_anim("walk_up", false)
		Facing.SIDE:
			_set_anim("walk_side", facing_left)


func _play_kick() -> void:
	is_kicking = true

	match facing:
		Facing.DOWN:
			_set_anim("kick_down", false)
		Facing.UP:
			_set_anim("kick_up", false)
		Facing.SIDE:
			_set_anim("kick_side", facing_left)

	_update_label("kick")


func _set_anim(anim_name: String, flip_horizontal: bool) -> void:
	sprite.flip_h = flip_horizontal

	if sprite.animation != anim_name:
		sprite.play(anim_name)

	_update_label(anim_name)


func _on_animated_sprite_2d_animation_finished() -> void:
	if sprite.animation.begins_with("kick"):
		is_kicking = false
		_play_idle()


func _update_label(state_name: String) -> void:
	if state_label:
		state_label.text = "State: %s" % state_name
