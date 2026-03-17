extends CanvasLayer

enum TooltipStyle {
	INFO,
	DANGER,
	UPGRADE
}

@export var tooltip_offset: Vector2 = Vector2(0, -10)
@export var appear_distance: float = 8.0
@export var enter_time: float = 0.16
@export var exit_time: float = 0.12
@export var max_width: float = 420.0
@export var screen_padding: float = 12.0
@export var target_gap: float = 10.0
@export var arrow_overlap: float = 2.0

@export var info_title_color: Color = Color("6d356f")
@export var info_text_color: Color = Color("6d356f")

@export var danger_title_color: Color = Color("8b2e4f")
@export var danger_text_color: Color = Color("8b2e4f")

@export var upgrade_title_color: Color = Color("6c3bb8")
@export var upgrade_text_color: Color = Color("6c3bb8")

@onready var root_box: Control = $Root
@onready var bubble: NinePatchRect = $Root/Bubble
@onready var content_margin: MarginContainer = $Root/Bubble/ContentMargin
@onready var vbox: VBoxContainer = $Root/Bubble/ContentMargin/VBox
@onready var title_label: Label = $Root/Bubble/ContentMargin/VBox/TitleLabel
@onready var message_label: Label = $Root/Bubble/ContentMargin/VBox/MessageLabel

@onready var arrow_top: TextureRect = $Root/ArrowTop
@onready var arrow_bottom: TextureRect = $Root/ArrowBottom
@onready var arrow_left: TextureRect = $Root/ArrowLeft
@onready var arrow_right: TextureRect = $Root/ArrowRight

var _tween: Tween
var _target_control: Control = null
var _showing: bool = false
var _current_style: int = TooltipStyle.INFO
var _current_side: String = "bottom"

func _ready() -> void:
	layer = 100
	root_box.visible = false
	root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.visible = false
	_hide_all_arrows()
	root_box.modulate = Color(1, 1, 1, 0)

func show_card(
	text: String,
	anchor_control: Control,
	custom_offset: Vector2 = Vector2.ZERO,
	title: String = "",
	style: int = TooltipStyle.INFO
) -> void:
	if anchor_control == null:
		return

	_target_control = anchor_control
	_current_style = style

	title_label.visible = not title.strip_edges().is_empty()
	title_label.text = title
	message_label.text = text

	_apply_style(style)
	await _refresh_size()

	var tooltip_pos: Vector2 = _get_best_position(anchor_control, custom_offset)
	_place_arrows(anchor_control)

	root_box.position = tooltip_pos + Vector2(0, appear_distance)
	root_box.scale = Vector2(0.98, 0.98)
	root_box.visible = true
	_showing = true

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(root_box, "position", tooltip_pos, enter_time)
	_tween.tween_property(root_box, "scale", Vector2.ONE, enter_time)
	_tween.tween_property(root_box, "modulate:a", 1.0, enter_time)

func hide_card() -> void:
	if not _showing:
		return

	_showing = false

	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(root_box, "position", root_box.position + Vector2(0, 6), exit_time)
	_tween.tween_property(root_box, "scale", Vector2(0.98, 0.98), exit_time)
	_tween.tween_property(root_box, "modulate:a", 0.0, exit_time)

	await _tween.finished

	if not _showing:
		root_box.visible = false
		_hide_all_arrows()
		_target_control = null

func _process(_delta: float) -> void:
	if not _showing:
		return
	if not is_instance_valid(_target_control):
		hide_card()
		return

	var tooltip_pos: Vector2 = _get_best_position(_target_control, Vector2.ZERO)
	root_box.position = tooltip_pos
	_place_arrows(_target_control)

func _apply_style(style: int) -> void:
	match style:
		TooltipStyle.DANGER:
			title_label.add_theme_color_override("font_color", danger_title_color)
			message_label.add_theme_color_override("font_color", danger_text_color)
		TooltipStyle.UPGRADE:
			title_label.add_theme_color_override("font_color", upgrade_title_color)
			message_label.add_theme_color_override("font_color", upgrade_text_color)
		_:
			title_label.add_theme_color_override("font_color", info_title_color)
			message_label.add_theme_color_override("font_color", info_text_color)

func _refresh_size() -> void:
	var title_font: Font = title_label.get_theme_font("font")
	var title_size_px: int = title_label.get_theme_font_size("font_size")

	var msg_font: Font = message_label.get_theme_font("font")
	var msg_size_px: int = message_label.get_theme_font_size("font_size")

	var title_size: Vector2 = Vector2.ZERO
	if title_label.visible:
		title_size = title_font.get_multiline_string_size(
			title_label.text,
			HORIZONTAL_ALIGNMENT_CENTER,
			max_width,
			title_size_px
		)

	var msg_size: Vector2 = msg_font.get_multiline_string_size(
		message_label.text,
		HORIZONTAL_ALIGNMENT_CENTER,
		max_width,
		msg_size_px
	)

	var separation: int = vbox.get_theme_constant("separation")

	var content_w: float = max(title_size.x, msg_size.x)
	var content_h: float = msg_size.y
	if title_label.visible:
		content_h += title_size.y + float(separation)

	var margin_left: int = content_margin.get_theme_constant("margin_left")
	var margin_top: int = content_margin.get_theme_constant("margin_top")
	var margin_right: int = content_margin.get_theme_constant("margin_right")
	var margin_bottom: int = content_margin.get_theme_constant("margin_bottom")

	var final_w: float = min(max_width, content_w) + margin_left + margin_right
	var final_h: float = content_h + margin_top + margin_bottom

	# 🔥 THIS IS THE FIX
	bubble.size = Vector2(final_w, final_h)
	root_box.size = bubble.size

	# Force labels to respect width
	title_label.custom_minimum_size = Vector2(min(max_width, title_size.x), 0)
	message_label.custom_minimum_size = Vector2(min(max_width, msg_size.x), 0)

	await get_tree().process_frame

func _get_best_position(control: Control, custom_offset: Vector2) -> Vector2:
	var rect: Rect2 = control.get_global_rect()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var bubble_size: Vector2 = bubble.size

	var preferred_above: Vector2 = Vector2(
		rect.position.x + rect.size.x * 0.5 - bubble_size.x * 0.5,
		rect.position.y - bubble_size.y - target_gap
	) + tooltip_offset + custom_offset

	var preferred_below: Vector2 = Vector2(
		rect.position.x + rect.size.x * 0.5 - bubble_size.x * 0.5,
		rect.position.y + rect.size.y + target_gap
	) + tooltip_offset + custom_offset

	var fits_above: bool = preferred_above.y >= screen_padding
	var fits_below: bool = preferred_below.y + bubble_size.y <= viewport_rect.size.y - screen_padding

	var pos: Vector2

	if fits_above:
		pos = preferred_above
		_current_side = "bottom"
	elif fits_below:
		pos = preferred_below
		_current_side = "top"
	else:
		pos = preferred_below
		_current_side = "top"

	pos.x = clamp(pos.x, screen_padding, viewport_rect.size.x - bubble_size.x - screen_padding)
	pos.y = clamp(pos.y, screen_padding, viewport_rect.size.y - bubble_size.y - screen_padding)

	return pos

func _place_arrows(control: Control) -> void:
	_hide_all_arrows()

	var rect: Rect2 = control.get_global_rect()
	var center_x: float = rect.position.x + rect.size.x * 0.5
	var center_y: float = rect.position.y + rect.size.y * 0.5

	match _current_side:
		"top":
			arrow_top.visible = true
			arrow_top.position.x = clamp(center_x - arrow_top.size.x * 0.5 - root_box.position.x, 8.0, bubble.size.x - arrow_top.size.x - 8.0)
			arrow_top.position.y = -arrow_top.size.y + arrow_overlap
		"bottom":
			arrow_bottom.visible = true
			arrow_bottom.position.x = clamp(center_x - arrow_bottom.size.x * 0.5 - root_box.position.x, 8.0, bubble.size.x - arrow_bottom.size.x - 8.0)
			arrow_bottom.position.y = bubble.size.y - arrow_overlap

func _hide_all_arrows() -> void:
	arrow_top.visible = false
	arrow_bottom.visible = false
	arrow_left.visible = false
	arrow_right.visible = false
