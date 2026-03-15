extends Control

@export var peak_1: float = 1.28
@export var peak_2: float = 1.42
@export var peak_3: float = 1.32

@export var rise_time: float = 0.26
@export var fall_time: float = 0.24
@export var phase_offset: float = 0.12
@export var reset_time: float = 0.14

@onready var button: TextureButton = $StatusButton
@onready var bar_1: TextureRect = $StatusButton/Bar1
@onready var bar_2: TextureRect = $StatusButton/Bar2
@onready var bar_3: TextureRect = $StatusButton/Bar3

var hovering: bool = false

var tween_1: Tween
var tween_2: Tween
var tween_3: Tween
var reset_tween: Tween

func _ready() -> void:
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)

	for bar in [bar_1, bar_2, bar_3]:
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	await get_tree().process_frame
	_setup_bar_pivots()
	_reset_bars_instant()

func _setup_bar_pivots() -> void:
	for bar in [bar_1, bar_2, bar_3]:
		bar.pivot_offset = Vector2(bar.size.x * 0.5, bar.size.y)

func _reset_bars_instant() -> void:
	for bar in [bar_1, bar_2, bar_3]:
		bar.scale = Vector2(1.0, 1.0)

func _on_mouse_entered() -> void:
	hovering = true

	if reset_tween:
		reset_tween.kill()
		reset_tween = null

	_kill_wave_tweens()
	_start_bar_wave(bar_1, peak_1, 0.0, "tween_1")
	_start_bar_wave(bar_2, peak_2, phase_offset, "tween_2")
	_start_bar_wave(bar_3, peak_3, phase_offset * 2.0, "tween_3")

func _on_mouse_exited() -> void:
	hovering = false
	_kill_wave_tweens()
	_reset_bars_smooth()

func _kill_wave_tweens() -> void:
	if tween_1:
		tween_1.kill()
		tween_1 = null
	if tween_2:
		tween_2.kill()
		tween_2 = null
	if tween_3:
		tween_3.kill()
		tween_3 = null

func _start_bar_wave(bar: TextureRect, peak: float, start_delay: float, tween_name: String) -> void:
	var t := create_tween()

	if tween_name == "tween_1":
		tween_1 = t
	elif tween_name == "tween_2":
		tween_2 = t
	else:
		tween_3 = t

	t.tween_interval(start_delay)
	t.set_loops()

	t.tween_property(
		bar,
		"scale",
		Vector2(1.0, peak),
		rise_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.tween_property(
		bar,
		"scale",
		Vector2(1.0, 1.0),
		fall_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _reset_bars_smooth() -> void:
	if reset_tween:
		reset_tween.kill()

	reset_tween = create_tween()

	for bar in [bar_1, bar_2, bar_3]:
		reset_tween.parallel().tween_property(
			bar,
			"scale",
			Vector2(1.0, 1.0),
			reset_time
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_status_button_pressed() -> void:
		print("Status clicked!")
