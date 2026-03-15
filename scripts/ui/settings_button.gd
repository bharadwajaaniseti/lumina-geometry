extends Control

@export var rotate_speed: float = 180.0
@export var hover_scale: float = 0.55
@export var hover_anim_time: float = 0.55

@onready var gear_button: TextureButton = $SettingsButton
@onready var gear_icon: TextureRect = $SettingsButton/GearIcon

var hovering: bool = false
var tween: Tween

func _ready() -> void:
	gear_button.mouse_entered.connect(_on_mouse_entered)
	gear_button.mouse_exited.connect(_on_mouse_exited)

	await get_tree().process_frame
	gear_icon.pivot_offset = gear_icon.size * 0.5

func _process(delta: float) -> void:
	if hovering:
		gear_icon.rotation_degrees += rotate_speed * delta

func _on_mouse_entered() -> void:
	hovering = true
	_scale_button(hover_scale)


func _on_mouse_exited() -> void:
	hovering = false
	_scale_button(0.5)

func _on_settings_button_pressed() -> void:
	print("Settings clicked!")

func _scale_button(target_scale: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(
		gear_button,
		"scale",
		Vector2(target_scale, target_scale),
		hover_anim_time
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
