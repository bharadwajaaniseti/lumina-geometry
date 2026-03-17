extends CanvasLayer

@export var tooltip_offset: Vector2 = Vector2(0, -14)
@export var appear_distance: float = 8.0
@export var enter_time: float = 0.16
@export var exit_time: float = 0.12
@export var max_width: float = 420.0
@export var screen_padding: float = 12.0

@export var background_texture: Texture2D = preload("res://assets/sprites/ui/panels/234x62 yellowhover.png")
@export var font_file: Font = preload("res://assets/fonts/ScribblesJE.ttf")
@export var font_size: int = 24
@export var font_color: Color = Color("6d356f")

@export var text_padding_left: float = 20.0
@export var text_padding_top: float = 15.0
@export var text_padding_right: float = 20.0
@export var text_padding_bottom: float = 15.0

var card: TextureRect
var message: Label
var tween: Tween

var _target_control: Control = null
var _showing: bool = false
var _base_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 100

	card = TextureRect.new()
	card.name = "HoverCard"
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate = Color(1, 1, 1, 0)
	card.position = Vector2.ZERO
	card.size = Vector2.ZERO
	card.texture = background_texture
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	message = Label.new()
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if font_file != null:
		message.add_theme_font_override("font", font_file)

	message.add_theme_font_size_override("font_size", font_size)
	message.add_theme_color_override("font_color", font_color)

	add_child(card)
	card.add_child(message)

func show_card(text: String, anchor_control: Control, custom_offset: Vector2 = Vector2.ZERO) -> void:
	if anchor_control == null:
		return

	_target_control = anchor_control
	message.text = text

	_refresh_size()

	var pos: Vector2 = _get_tooltip_position(anchor_control, custom_offset)
	_base_position = pos

	card.position = pos + Vector2(0, appear_distance)
	card.scale = Vector2(0.98, 0.98)
	card.visible = true
	_showing = true

	if tween != null and tween.is_valid():
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", _base_position, enter_time)
	tween.tween_property(card, "scale", Vector2.ONE, enter_time)
	tween.tween_property(card, "modulate:a", 1.0, enter_time)

func hide_card() -> void:
	if not _showing:
		return

	_showing = false

	if tween != null and tween.is_valid():
		tween.kill()

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(card, "position", _base_position + Vector2(0, 6), exit_time)
	tween.tween_property(card, "scale", Vector2(0.98, 0.98), exit_time)
	tween.tween_property(card, "modulate:a", 0.0, exit_time)

	await tween.finished

	if not _showing:
		card.visible = false
		_target_control = null

func _process(_delta: float) -> void:
	if not _showing:
		return

	if is_instance_valid(_target_control):
		card.position = _get_tooltip_position(_target_control)

func _refresh_size() -> void:
	var font_ref: Font = message.get_theme_font("font")
	var current_font_size: int = message.get_theme_font_size("font_size")

	var text_size: Vector2 = font_ref.get_multiline_string_size(
		message.text,
		HORIZONTAL_ALIGNMENT_CENTER,
		max_width,
		current_font_size
	)

	var final_width: float = text_size.x + text_padding_left + text_padding_right
	var final_height: float = text_size.y + text_padding_top + text_padding_bottom

	card.size = Vector2(final_width, final_height)

	message.position = Vector2(text_padding_left, text_padding_top)
	message.size = Vector2(
		final_width - text_padding_left - text_padding_right,
		final_height - text_padding_top - text_padding_bottom
	)

func _get_tooltip_position(control: Control, custom_offset: Vector2 = Vector2.ZERO) -> Vector2:
	var rect: Rect2 = control.get_global_rect()
	var tooltip_size: Vector2 = card.size

	var above: Vector2 = Vector2(
		rect.position.x + (rect.size.x * 0.5) - (tooltip_size.x * 0.5),
		rect.position.y - tooltip_size.y - 10.0
	) + tooltip_offset + custom_offset

	if above.y < screen_padding:
		var below: Vector2 = Vector2(
			rect.position.x + (rect.size.x * 0.5) - (tooltip_size.x * 0.5),
			rect.position.y + rect.size.y + 10.0
		) + tooltip_offset + custom_offset
		return _clamp_to_viewport(below)

	return _clamp_to_viewport(above)

func _clamp_to_viewport(pos: Vector2) -> Vector2:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var tooltip_size: Vector2 = card.size

	pos.x = clamp(pos.x, screen_padding, viewport_rect.size.x - tooltip_size.x - screen_padding)
	pos.y = clamp(pos.y, screen_padding, viewport_rect.size.y - tooltip_size.y - screen_padding)

	return pos
