extends Control
class_name MetaTreeScreen

signal closed
signal shape_level_changed(shape_id: StringName, new_level: int)

@export var block_scene: PackedScene

@onready var title_label: Label = $MainPanel/Margin/VBoxRoot/TopBar/TitleLabel
@onready var shape_name_label: Label = $MainPanel/Margin/VBoxRoot/TopBar/ShapeNameLabel
@onready var shape_level_label: Label = $MainPanel/Margin/VBoxRoot/TopBar/ShapeLevelLabel
@onready var close_button: Button = $MainPanel/Margin/VBoxRoot/TopBar/CloseButton

@onready var shape_preview: TextureRect = $MainPanel/Margin/VBoxRoot/ContentRow/LeftInfoPanel/LeftMargin/LeftVBox/ShapePreview
@onready var core_label: Label = $MainPanel/Margin/VBoxRoot/ContentRow/LeftInfoPanel/LeftMargin/LeftVBox/CoreLabel

@onready var hover_node_title: Label = $MainPanel/Margin/VBoxRoot/ContentRow/LeftInfoPanel/LeftMargin/LeftVBox/HoverNodeCard/CardMargin/CardVBox/HoverNodeTitle
@onready var hover_node_effect: Label = $MainPanel/Margin/VBoxRoot/ContentRow/LeftInfoPanel/LeftMargin/LeftVBox/HoverNodeCard/CardMargin/CardVBox/HoverNodeEffect
@onready var hover_node_cost: Label = $MainPanel/Margin/VBoxRoot/ContentRow/LeftInfoPanel/LeftMargin/LeftVBox/HoverNodeCard/CardMargin/CardVBox/HoverNodeCost
@onready var hover_node_owned: Label = $MainPanel/Margin/VBoxRoot/ContentRow/LeftInfoPanel/LeftMargin/LeftVBox/HoverNodeCard/CardMargin/CardVBox/HoverNodeOwned
@onready var buy_button: Button = $MainPanel/Margin/VBoxRoot/ContentRow/LeftInfoPanel/LeftMargin/LeftVBox/HoverNodeCard/CardMargin/CardVBox/BuyButton

@onready var progress_label: Label = $MainPanel/Margin/VBoxRoot/ContentRow/LeftInfoPanel/LeftMargin/LeftVBox/HoverNodeCard/CardMargin/CardVBox/ProgressLabel
@onready var upgrade_grid: GridContainer = $MainPanel/Margin/VBoxRoot/ContentRow/RightTreePanel/TreeMargin/UpgradeGrid

@onready var nodes_owned_label: Label = $MainPanel/Margin/VBoxRoot/BottomBar/NodesOwnedLabel
@onready var next_level_label: Label = $MainPanel/Margin/VBoxRoot/BottomBar/NextLevelLabel

var _shape_def
var _tree_def: ShapeMetaTreeDef
var _selected_node: MetaUpgradeNodeDef = null
var _blocks: Dictionary = {}

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	hide()

func open_for_shape(shape_def, tree_def: ShapeMetaTreeDef) -> void:
	_shape_def = shape_def
	_tree_def = tree_def
	_selected_node = null
	show()
	move_to_front()
	_rebuild()

func _rebuild() -> void:
	for child in upgrade_grid.get_children():
		child.queue_free()

	_blocks.clear()

	if _tree_def == null:
		_clear_screen()
		return

	if block_scene == null:
		push_error("MetaTreeScreen block_scene is not assigned.")
		return

	upgrade_grid.columns = max(_tree_def.columns, 1)

	_update_shape_header()
	_update_shape_preview()
	_update_core_label()

	for node_def in _tree_def.nodes:
		var block_instance = block_scene.instantiate()
		var block: MetaUpgradeBlock = block_instance as MetaUpgradeBlock
		if block == null:
			continue

		var rank: int = Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(node_def.id))
		var available: bool = _is_node_available(node_def)

		upgrade_grid.add_child(block)
		block.custom_minimum_size = Vector2(100, 100)
		block.setup(node_def, rank, available)
		block.pressed_node.connect(_on_block_pressed)

		_blocks[node_def.id] = block

	if _selected_node == null and _tree_def.nodes.size() > 0:
		_selected_node = _tree_def.nodes[0]

	_update_block_selection_visuals()
	_update_hover_card()
	_update_progress()

func _clear_screen() -> void:
	shape_name_label.text = "-"
	shape_level_label.text = "Level 1"
	core_label.text = "Cores: 0"
	shape_preview.texture = null

	hover_node_title.text = "Select a node"
	hover_node_effect.text = "-"
	hover_node_cost.text = "-"
	hover_node_owned.text = "-"
	buy_button.text = "Buy"
	buy_button.disabled = true

	nodes_owned_label.text = "Ranks Owned: 0 / 0"
	next_level_label.text = "Next Level: 0 / 0"
	progress_label.text = "Next Level: 0 / 0"

func _update_shape_header() -> void:
	var display_name := str(_tree_def.shape_id)

	if _shape_def != null:
		var dn = _shape_def.get("display_name")
		var sid = _shape_def.get("id")

		if dn != null and str(dn).strip_edges() != "":
			display_name = str(dn)
		elif sid != null and str(sid).strip_edges() != "":
			display_name = str(sid)

	shape_name_label.text = display_name
	shape_level_label.text = "Level %d" % get_current_shape_level()

func _update_shape_preview() -> void:
	if _shape_def == null:
		shape_preview.texture = null
		return

	var tex = _shape_def.get("texture")
	if tex == null:
		tex = _shape_def.get("icon")

	shape_preview.texture = tex

func _update_core_label() -> void:
	if _tree_def == null:
		core_label.text = "Cores: 0"
		return

	core_label.text = "Cores: %d" % Game_State.get_shape_cores(str(_tree_def.shape_id))

func _is_node_available(node_def: MetaUpgradeNodeDef) -> bool:
	var rank: int = Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(node_def.id))
	if rank >= node_def.max_rank:
		return true

	for req in node_def.required_node_ids:
		if Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(req)) <= 0:
			return false

	return true

func _on_block_pressed(node_id: StringName) -> void:
	_selected_node = _find_node_def(node_id)
	_update_block_selection_visuals()
	_update_hover_card()

func _find_node_def(node_id: StringName) -> MetaUpgradeNodeDef:
	if _tree_def == null:
		return null

	for node_def in _tree_def.nodes:
		if node_def.id == node_id:
			return node_def

	return null

func _get_node_cost(node_def: MetaUpgradeNodeDef) -> int:
	var rank: int = Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(node_def.id))
	return node_def.base_cost_cores + (node_def.cost_per_rank * rank)

func _get_node_current_value(node_def: MetaUpgradeNodeDef) -> float:
	var rank: int = Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(node_def.id))
	if rank <= 0:
		return 0.0
	return node_def.base_value + (node_def.value_per_rank * float(rank - 1))

func _get_node_next_value(node_def: MetaUpgradeNodeDef) -> float:
	var rank: int = Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(node_def.id))
	return node_def.base_value + (node_def.value_per_rank * float(rank))

func _format_value(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return str(snappedf(value, 0.01))

func _get_node_effect_text(node_def: MetaUpgradeNodeDef) -> String:
	var rank: int = Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(node_def.id))

	if node_def.max_rank <= 1:
		return "%s +%s" % [str(node_def.stat_key), _format_value(node_def.base_value)]

	if rank <= 0:
		var first_value := node_def.base_value
		var last_value := node_def.base_value + (node_def.value_per_rank * float(node_def.max_rank - 1))
		return "%s %s to %s" % [
			str(node_def.stat_key),
			_format_value(first_value),
			_format_value(last_value)
		]

	if rank >= node_def.max_rank:
		return "%s Maxed (%s)" % [
			str(node_def.stat_key),
			_format_value(_get_node_current_value(node_def))
		]

	return "%s %s to %s" % [
		str(node_def.stat_key),
		_format_value(_get_node_current_value(node_def)),
		_format_value(_get_node_next_value(node_def))
	]

func _update_hover_card() -> void:
	if _selected_node == null or _tree_def == null:
		hover_node_title.text = "Select a node"
		hover_node_effect.text = "-"
		hover_node_cost.text = "-"
		hover_node_owned.text = "-"
		buy_button.disabled = true
		buy_button.text = "Buy"
		return

	var rank: int = Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(_selected_node.id))
	var cost: int = _get_node_cost(_selected_node)
	var available: bool = _is_node_available(_selected_node)
	var maxed: bool = rank >= _selected_node.max_rank

	hover_node_title.text = _selected_node.title
	hover_node_effect.text = _get_node_effect_text(_selected_node)
	hover_node_cost.text = "%d Cores" % cost
	hover_node_owned.text = "%d / %d" % [rank, _selected_node.max_rank]

	if maxed:
		buy_button.text = "Maxed"
		buy_button.disabled = true
	elif not available:
		buy_button.text = "Locked"
		buy_button.disabled = true
	elif Game_State.get_shape_cores(str(_tree_def.shape_id)) < cost:
		buy_button.text = "Not Enough Cores"
		buy_button.disabled = true
	else:
		buy_button.text = "Buy"
		buy_button.disabled = false

func _update_block_selection_visuals() -> void:
	for key in _blocks.keys():
		var block: MetaUpgradeBlock = _blocks[key]
		if block == null:
			continue

		var is_selected := false
		if _selected_node != null:
			is_selected = StringName(key) == _selected_node.id

		block.set_selected(is_selected)

func _on_buy_pressed() -> void:
	if _selected_node == null or _tree_def == null:
		return

	var rank: int = Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(_selected_node.id))
	if rank >= _selected_node.max_rank:
		return

	if not _is_node_available(_selected_node):
		return

	var cost: int = _get_node_cost(_selected_node)
	if not Game_State.spend_shape_cores(str(_tree_def.shape_id), cost):
		return

	var old_level: int = get_current_shape_level()

	Game_State.increase_shape_upgrade_node_rank(
		str(_tree_def.shape_id),
		str(_selected_node.id),
		1,
		true,
		1
	)

	var new_level: int = get_current_shape_level()

	_rebuild()

	if new_level > old_level:
		shape_level_changed.emit(_tree_def.shape_id, new_level)

func get_total_owned_ranks() -> int:
	if _tree_def == null:
		return 0

	var total := 0
	for node_def in _tree_def.nodes:
		total += Game_State.get_shape_upgrade_node_rank(str(_tree_def.shape_id), str(node_def.id))

	return total

func get_current_shape_level() -> int:
	if _tree_def == null:
		return 1

	return Game_State.get_shape_level(str(_tree_def.shape_id)) + 1

func _update_progress() -> void:
	if _tree_def == null:
		nodes_owned_label.text = "Ranks Owned: 0 / 0"
		next_level_label.text = "Next Level: 0 / 0"
		progress_label.text = "Next Level: 0 / 0"
		return

	var total_ranks: int = get_total_owned_ranks()
	var max_ranks := 0

	for node_def in _tree_def.nodes:
		max_ranks += node_def.max_rank

	nodes_owned_label.text = "Ranks Owned: %d / %d" % [total_ranks, max_ranks]

	var internal_level: int = Game_State.get_shape_level(str(_tree_def.shape_id))
	if internal_level >= Game_State.SHAPE_MAX_LEVEL:
		next_level_label.text = "Max Level Reached"
		progress_label.text = "Max Level Reached"
		return

	var progress_in_tier: int = Game_State.get_shape_level_progress_in_current_tier(str(_tree_def.shape_id))
	var needed: int = Game_State.get_shape_points_needed_for_next_level(str(_tree_def.shape_id))
	var gained_in_tier: int = Game_State.SHAPE_POINTS_PER_LEVEL - needed if needed > 0 else Game_State.SHAPE_POINTS_PER_LEVEL

	next_level_label.text = "Next Level: %d / %d" % [gained_in_tier, Game_State.SHAPE_POINTS_PER_LEVEL]
	progress_label.text = next_level_label.text

func _on_close_pressed() -> void:
	hide()
	closed.emit()
