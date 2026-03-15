extends PanelContainer
class_name MetaUpgradeBlock

signal pressed_node(node_id: StringName)

@onready var block_button: Button = $BlockButton
@onready var rank_label: Label = $RankLabel

@export var locked_color: Color = Color("D7D1E3")
@export var available_color: Color = Color("8D9AF0")
@export var owned_color: Color = Color("6E7FE8")
@export var maxed_color: Color = Color("5C75E6")

@export var available_outline_color: Color = Color("B58AE8")
@export var highlight_border_color: Color = Color("F2C300")
@export var normal_border_color: Color = Color(0, 0, 0, 0)

@export var selected_outline_color: Color = Color("6B2FA3")
@export var selected_outline_width: int = 4
@export var available_outline_width: int = 2

@export var border_width: int = 0
@export var highlight_border_width: int = 4

var node_def: MetaUpgradeNodeDef
var current_rank: int = 0
var is_available: bool = false
var is_selected: bool = false

func _ready() -> void:
	block_button.pressed.connect(_on_pressed)

func setup(def: MetaUpgradeNodeDef, rank: int, available: bool) -> void:
	node_def = def
	current_rank = rank
	is_available = available
	_update_rank_label()
	_update_visual()

func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_visual()

func _update_rank_label() -> void:
	if node_def == null:
		rank_label.visible = false
		return

	rank_label.visible = false
	rank_label.text = "%d/%d" % [current_rank, node_def.max_rank]

func _update_visual() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _get_base_fill_color()

	var use_highlight := node_def != null and node_def.highlight_border
	var bw := highlight_border_width if use_highlight else border_width
	var bc := highlight_border_color if use_highlight else normal_border_color

	if current_rank <= 0 and is_available and not use_highlight:
		bw = max(bw, available_outline_width)
		bc = available_outline_color

	if is_selected:
		bw = max(bw, selected_outline_width)
		bc = selected_outline_color

	style.border_width_left = bw
	style.border_width_top = bw
	style.border_width_right = bw
	style.border_width_bottom = bw
	style.border_color = bc

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

	if current_rank > 0:
		return owned_color

	if is_available:
		return available_color

	return locked_color

func _on_pressed() -> void:
	if node_def != null:
		pressed_node.emit(node_def.id)
