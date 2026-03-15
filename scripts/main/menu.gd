extends Control
class_name MainMenu

enum ConversionMode {
	SQRT,
	RATIO
}

## Scene loaded when the player presses Phase I.
## Example: "res://scenes/gamephase/Phase1.tscn"
@export var phase1_scene: String = "res://scenes/gameplay/phase_1/Phase1.tscn"
@export var inventory_scene: String = "res://scenes/inventory/inventory.tscn"


# =========================================================
# CONVERTER BACKEND
# =========================================================
@export_group("Converter")

## Reserved energy processed each second while converter is running.
## Example: 5000 = 5000 Reserved/sec.
@export var auto_convert_reserved_per_second: float = 5000.0

## Time between backend conversion steps (seconds).
## Formula: chunk = rate * interval.
## Example: 5000 * 0.20 = 1000 per step.
@export var conversion_step_interval: float = 0.20

## How often the game auto-saves during conversion.
@export var auto_save_interval: float = 1.0

## If true, converter starts enabled when Menu opens.
@export var converter_starts_enabled: bool = true

## Optional tint when converter is paused.
## Example: lower alpha helps show "offline / paused" state.
@export var converter_paused_modulate: Color = Color(0.75, 0.75, 0.75, 0.95)

## Optional tint when converter is active.
@export var converter_active_modulate: Color = Color(1, 1, 1, 1)

# =========================================================
# CONVERSION FORMULA
# =========================================================
@export_subgroup("Conversion Formula")

## Formula used for Reserved → Converted.
## SQRT  = diminishing returns.
## RATIO = linear conversion.
@export var conversion_mode: ConversionMode = ConversionMode.SQRT

## Used only when Conversion Mode = RATIO.
@export var conversion_ratio: float = 0.001

## Used only when Conversion Mode = SQRT.
@export var sqrt_multiplier: float = 1.0

# =========================================================
# CONVERTER VISUALS
# =========================================================
@export_group("Converter Visuals")

## Speed at which displayed numbers catch up to real values.
@export var display_lerp_speed: float = 4.0

## Extra catch-up speed applied right after a Game_State change.
@export var burst_lerp_speed: float = 12.0

## How long the burst lerp remains active after a bank / convert update.
@export var burst_lerp_duration: float = 0.18

## Pending Converted needed for gears to reach full speed.
@export var pending_buffer_for_full_speed: float = 20.0

## Minimum gear activity while converter is active and Reserve exists.
@export var minimum_activity_ratio: float = 0.25

## Scale used for the Converted number pop animation.
@export var converted_pop_scale: float = 1.12

## Maximum brightness of the glow pulse on each conversion tick.
@export var glow_peak_alpha: float = 0.22

@onready var lbl_reserved: Label = $BottomMargin/TextureRect/lblreserved
@onready var lbl_converted: Label = $BottomMargin/TextureRect/lblconverted
@onready var gear_group: Node2D = $BottomMargin/TextureRect/GearGroup
@onready var glow_pulse: ColorRect = $BottomMargin/TextureRect/GlowPulse
@onready var btn_converter: BaseButton = $BottomMargin/TextureRect/ConvertorButton

@onready var lbl_title: Label = $TopBar/Title
@onready var btn_inventory: TextureButton = $SideMargin/VBoxContainer/InventoryBtnWrap
@onready var btn_phase1: TextureButton = $SideMargin/VBoxContainer/Phase1BtnWrap
@onready var dialog: AcceptDialog = $Dialogs/Info

var title_hovering: bool = false
var title_tween: Tween
var title_colors := [
	Color("ff5858ff"),
	Color("ffe658ff"),
	Color("562a84ff"),
	Color("58ffecff"),
	Color("8b9099ff")
]
var title_color_index: int = 0

var _converted_pop_tween: Tween
var _glow_tween: Tween
var _converted_base_scale: Vector2 = Vector2.ONE

var _display_reserved: float = 0.0
var _display_converted: float = 0.0
var _target_reserved: float = 0.0
var _target_converted: float = 0.0

var _save_timer: float = 0.0
var _conversion_timer: float = 0.0
var _pending_converted: int = 0
var _burst_timer: float = 0.0

var _converter_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	Game_State.load_from_disk()

	_converter_enabled = converter_starts_enabled

	_target_reserved = Game_State.stored_energy
	_target_converted = Game_State.converted_energy
	_display_reserved = _target_reserved
	_display_converted = _target_converted
	_converted_base_scale = lbl_converted.scale

	if glow_pulse != null:
		glow_pulse.modulate.a = 0.0

	_apply_label_text_immediately()

	if not Game_State.changed.is_connected(_update_bank_labels):
		Game_State.changed.connect(_update_bank_labels)

	if Runtime != null and Runtime.has_signal("runtime_banked"):
		if not Runtime.runtime_banked.is_connected(_on_runtime_banked):
			Runtime.runtime_banked.connect(_on_runtime_banked)

	if gear_group != null and gear_group.has_signal("pulse"):
		gear_group.pulse.connect(_on_gear_pulse)

	lbl_title.mouse_entered.connect(_on_title_hover_entered)
	lbl_title.mouse_exited.connect(_on_title_hover_exited)

	btn_phase1.pressed.connect(_on_phase1_pressed)
	btn_inventory.pressed.connect(_on_inventory_pressed)

	if btn_converter != null:
		btn_converter.pressed.connect(_on_converter_button_pressed)

	_apply_converter_visual_state()
	_update_converter_visuals()

func _process(delta: float) -> void:
	_run_converter_backend(delta)
	_update_converter_visuals()
	_update_display_numbers(delta)

	if _burst_timer > 0.0:
		_burst_timer = max(_burst_timer - delta, 0.0)

func _run_converter_backend(delta: float) -> void:
	_save_timer += delta

	if _converter_enabled and Game_State.stored_energy > 0.0:
		_conversion_timer += delta

		while _conversion_timer >= conversion_step_interval:
			_conversion_timer -= conversion_step_interval

			var chunk_amount: float = auto_convert_reserved_per_second * conversion_step_interval
			var gained: int = Game_State.consume_reserved_chunk(
				chunk_amount,
				int(conversion_mode),
				conversion_ratio,
				sqrt_multiplier
			)

			if gained > 0:
				_pending_converted += gained
				_kick_display_burst()
	else:
		# Avoid giant catch-up bursts when resuming after a long pause.
		_conversion_timer = 0.0

	if _save_timer >= auto_save_interval:
		_save_timer = 0.0
		Game_State.save_to_disk()

func _update_converter_visuals() -> void:
	if gear_group == null:
		return

	var ratio: float = 0.0

	if _converter_enabled and (Game_State.stored_energy > 0.0 or _pending_converted > 0):
		var buffered_ratio: float = min(float(_pending_converted) / pending_buffer_for_full_speed, 1.0)
		ratio = max(minimum_activity_ratio, buffered_ratio)

	if gear_group.has_method("set_paused"):
		gear_group.call("set_paused", not _converter_enabled)

	if gear_group.has_method("set_activity_ratio"):
		gear_group.call("set_activity_ratio", ratio)

func _update_display_numbers(delta: float) -> void:
	var speed: float = display_lerp_speed
	if _burst_timer > 0.0:
		speed = max(speed, burst_lerp_speed)

	var t: float = clamp(speed * delta, 0.0, 1.0)

	_display_reserved = lerp(_display_reserved, _target_reserved, t)
	_display_converted = lerp(_display_converted, _target_converted, t)

	if abs(_display_reserved - _target_reserved) < 0.5:
		_display_reserved = _target_reserved

	if abs(_display_converted - _target_converted) < 0.5:
		_display_converted = _target_converted

	lbl_reserved.text = _fmt(_display_reserved)
	lbl_converted.text = _fmt(_display_converted)

func _on_gear_pulse() -> void:
	if not _converter_enabled:
		return

	if _pending_converted <= 0:
		return

	Game_State.add_converted(1)
	_pending_converted -= 1

	_play_converter_glow_pulse()
	_play_converted_pop()
	_kick_display_burst()

func _on_title_hover_entered() -> void:
	if title_hovering:
		return

	title_hovering = true
	title_color_index += 1
	if title_color_index >= title_colors.size():
		title_color_index = 0

	_cycle_title_colors()

func _on_title_hover_exited() -> void:
	title_hovering = false

	if title_tween:
		title_tween.kill()
		title_tween = null

func _cycle_title_colors() -> void:
	if not title_hovering:
		return

	var next_color: Color = title_colors[title_color_index]

	if title_tween:
		title_tween.kill()
		title_tween = null

	var from_color: Color = lbl_title.get_theme_color("font_color")

	title_tween = create_tween()
	title_tween.tween_method(
		func(c: Color) -> void:
			lbl_title.add_theme_color_override("font_color", c),
		from_color,
		next_color,
		1.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	title_tween.finished.connect(_on_title_color_step)

func _on_title_color_step() -> void:
	if not title_hovering:
		return

	title_color_index += 1
	if title_color_index >= title_colors.size():
		title_color_index = 0

	_cycle_title_colors()

func _update_bank_labels() -> void:
	_target_reserved = Game_State.stored_energy
	_target_converted = Game_State.converted_energy
	_kick_display_burst()

func _apply_label_text_immediately() -> void:
	lbl_reserved.text = _fmt(_display_reserved)
	lbl_converted.text = _fmt(_display_converted)

func _kick_display_burst() -> void:
	_burst_timer = burst_lerp_duration

func _on_runtime_banked(_raw_amount: float, _reserve_amount: float) -> void:
	_target_reserved = Game_State.stored_energy
	_target_converted = Game_State.converted_energy
	_kick_display_burst()

func _fmt(v: float) -> String:
	var s: String = str(int(round(v)))
	var out: String = ""
	var count: int = 0

	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count == 3 and i != 0:
			out = "," + out
			count = 0

	return out

func _play_converter_glow_pulse() -> void:
	if glow_pulse == null:
		return

	if _glow_tween:
		_glow_tween.kill()

	glow_pulse.modulate.a = 0.0

	_glow_tween = create_tween()
	_glow_tween.tween_property(glow_pulse, "modulate:a", glow_peak_alpha, 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(glow_pulse, "modulate:a", 0.0, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _play_converted_pop() -> void:
	if lbl_converted == null:
		return

	if _converted_pop_tween:
		_converted_pop_tween.kill()

	lbl_converted.scale = _converted_base_scale

	_converted_pop_tween = create_tween()
	_converted_pop_tween.tween_property(
		lbl_converted,
		"scale",
		_converted_base_scale * converted_pop_scale,
		0.08
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_converted_pop_tween.tween_property(
		lbl_converted,
		"scale",
		_converted_base_scale,
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _on_phase1_pressed() -> void:
	Game_State.save_to_disk()
	get_tree().change_scene_to_file(phase1_scene)

func _on_inventory_pressed() -> void:
	get_tree().change_scene_to_file(inventory_scene)

func _on_converter_button_pressed() -> void:
	_converter_enabled = not _converter_enabled
	_apply_converter_visual_state()
	_update_converter_visuals()

func _apply_converter_visual_state() -> void:
	if btn_converter != null:
		btn_converter.modulate = converter_active_modulate if _converter_enabled else converter_paused_modulate

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game_State.save_to_disk()
		get_tree().quit()
