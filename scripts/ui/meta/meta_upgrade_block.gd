extends PanelContainer
class_name MetaUpgradeBlock

signal hovered(node_id: StringName)
signal unhovered
signal pressed_node(node_id: StringName)

@onready var block_button: Button = $BlockButton
@onready var rank_label: Label = $RankLabel

@export var locked_color: Color = Color("AEBBEE")
@export var available_color: Color = Color("8799EA")
@export var maxed_color: Color = Color("5C75E6")
@export var highlight_border_color: Color = Color("F2C300")
@export var normal_border_color: Color = Color(0, 0, 0, 0)

@export var hover_brightness: float = 0.08
@export var border_width: int = 0
@export var highlight_border_width: int = 4

var node_def: MetaUpgradeNodeDef
var current_rank: int = 0
var is_available: bool = false
var is_hovered: bool = false

func _ready() -> void:
	block_button.mouse_entered.connect(_on_mouse_entered)
	block_button.mouse_exited.connect(_on_mouse_exited)
	block_button.pressed.connect(_on_pressed)

func setup(def: MetaUpgradeNodeDef, rank: int, available: bool) -> void:
	node_def = def
	current_rank = rank
	is_available = available
	_update_rank_label()
	_update_visual()

func _update_rank_label() -> void:
	if node_def == null:
		rank_label.visible = false
		return

	# Hidden for clean look. Turn on later if you want rank visible on block.
	rank_label.visible = false
	rank_label.text = "%d/%d" % [current_rank, node_def.max_rank]

func _update_visual() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _get_final_fill_color()

	var use_highlight := node_def != null and node_def.highlight_border
	var bw := highlight_border_width if use_highlight else border_width

	style.border_width_left = bw
	style.border_width_top = bw
	style.border_width_right = bw
	style.border_width_bottom = bw
	style.border_color = highlight_border_color if use_highlight else normal_border_color

	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	add_theme_stylebox_override("panel", style)

func _get_base_fill_color() -> Color:
	if node_def == null:
		return locked_color

	if current_rank >= node_def.max_rank:
		return maxed_color

	if is_available:
		return available_color

	return locked_color

func _get_final_fill_color() -> Color:
	var c := _get_base_fill_color()

	if is_hovered:
		c.r = min(c.r + hover_brightness, 1.0)
		c.g = min(c.g + hover_brightness, 1.0)
		c.b = min(c.b + hover_brightness, 1.0)

	return c

func _on_mouse_entered() -> void:
	is_hovered = true
	_update_visual()

	if node_def != null:
		hovered.emit(node_def.id)

func _on_mouse_exited() -> void:
	is_hovered = false
	_update_visual()
	unhovered.emit()

func _on_pressed() -> void:
	if node_def != null:
		pressed_node.emit(node_def.id)
