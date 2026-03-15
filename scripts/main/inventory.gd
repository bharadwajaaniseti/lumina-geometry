extends Control

@export var menu_scene: String = "res://scenes/menu/Menu.tscn"
@export var phase1_scene: String = "res://scenes/gameplay/phase_1/Phase1.tscn"

@export var inventory_db: InventoryShapeDB
@export var locked_icon: Texture2D
@export var slot_scene: PackedScene

# Map shape id -> ShapeMetaTreeDef resource
# Example in inspector:
# {
#   "circle": preload("res://data/meta/circle_meta_tree.tres"),
#   "triangle": preload("res://data/meta/triangle_meta_tree.tres")
# }
@export var meta_tree_defs: Dictionary = {}

var _selected_slot_index: int = 0

var _slot_buttons: Array[InventoryShapeSlot] = []
var _level_boxes: Array[TextureRect] = []

@onready var energy_label: Label = $SafeMargin/MainVBox/TopBar2/EnergyLabel
@onready var shape_grid: GridContainer = $SafeMargin/MainVBox/ContentRow/LeftPanel/ShpaeGrid

@onready var unlocked_panel: VBoxContainer = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked
@onready var locked_panel: MarginContainer = $SafeMargin/MainVBox/ContentRow/RightPanel/Locked

@onready var level_label: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/LevelRow/LevelLabel
@onready var level_boxes_root: HBoxContainer = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/LevelRow/LevelBoxes
@onready var currency_label: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/StatsPanel/StatsMargin/StatsVBox/StatsHeaderRow/CurrencyLabel

@onready var damage_value: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/StatsPanel/StatsMargin/StatsVBox/StatsColumns/LeftStatsColumn/DamageRow/DamageValue
@onready var attack_speed_value: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/StatsPanel/StatsMargin/StatsVBox/StatsColumns/LeftStatsColumn/AttackSpeedRow/AttackSpeedValue
@onready var projectile_count_value: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/StatsPanel/StatsMargin/StatsVBox/StatsColumns/LeftStatsColumn/ProjectileCountRow/ProjectileCountValue
@onready var projectile_size_value: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/StatsPanel/StatsMargin/StatsVBox/StatsColumns/LeftStatsColumn/ProjectileSizeRow/ProjectileSizeValue
@onready var crit_chance_value: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/StatsPanel/StatsMargin/StatsVBox/StatsColumns/RightStatsColumn/CritChaceRow/CritChanceValue
@onready var crit_damage_value: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/StatsPanel/StatsMargin/StatsVBox/StatsColumns/RightStatsColumn/CritDamageRow/CritDamageValue

@onready var ability1_description: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard1/MarginContainer/Ability1Root/Ability1Top/Ability1Description
@onready var ability1_name: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard1/MarginContainer/Ability1Root/Ability1Bottom/Ability1NameBlock/Ability1Name
@onready var ability1_damage: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard1/MarginContainer/Ability1Root/Ability1Bottom/Ability1NameBlock/Ability1Damage
@onready var ability1_cooldown: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard1/MarginContainer/Ability1Root/Ability1Bottom/Ability1NameBlock/Ability1Cooldown
@onready var ability1_type: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard1/MarginContainer/Ability1Root/Ability1Bottom/Ability1ToggleWrap/Ability1ToggleLabel

@onready var ability2_description: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard2/MarginContainer/Ability2Root/Ability2Top/Ability2Description
@onready var ability2_name: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard2/MarginContainer/Ability2Root/Ability2Bottom/Ability2NameBlock/Ability2Name
@onready var ability2_damage: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard2/MarginContainer/Ability2Root/Ability2Bottom/Ability2NameBlock/Ability2Damage
@onready var ability2_cooldown: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard2/MarginContainer/Ability2Root/Ability2Bottom/Ability2NameBlock/Ability2Cooldown
@onready var ability2_type: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/AbilityCardsRow/AbilityCard2/MarginContainer/Ability2Root/Ability2Bottom/Ability2ToggleWrap/Ability2ToggleLabel

@onready var train_button: TextureButton = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/BottomButtonsRow/TrainSection/TrainButton
@onready var train_button_label: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/BottomButtonsRow/TrainSection/TrainButton/Label

@onready var upgrade_button: TextureButton = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/BottomButtonsRow/UpgradeSection/UpgradeButton
@onready var upgrade_button_label: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Unlocked/BottomButtonsRow/UpgradeSection/UpgradeButton/Label

@onready var locked_title: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Locked/Control/MarginContainer/VBoxContainer/LockedLabel
@onready var locked_info: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Locked/Control/MarginContainer/VBoxContainer/TrainInfo
@onready var locked_phase_button: TextureButton = $SafeMargin/MainVBox/ContentRow/RightPanel/Locked/Control/MarginContainer/VBoxContainer/InventoryBtnWrap
@onready var locked_phase_button_label: Label = $SafeMargin/MainVBox/ContentRow/RightPanel/Locked/Control/MarginContainer/VBoxContainer/InventoryBtnWrap/Label

# Add MetaTreeScreen as a child somewhere in this scene, then point this path to it.
@onready var meta_tree_screen: MetaTreeScreen = $MetaTreeScreen


func _ready() -> void:
	if inventory_db == null:
		push_error("Inventory DB is not assigned on Inventory scene.")
		return

	_collect_level_boxes()
	_apply_default_unlocks()
	_connect_signals()
	_refresh_energy_label()
	_build_slot_nodes()
	Game_State.add_shape_cores("circle", 100)
	if inventory_db.size() > 0:
		_select_slot(0)
	else:
		_show_locked_fallback()


func _apply_default_unlocks() -> void:
	for i in range(inventory_db.size()):
		var def: InventoryShapeDef = inventory_db.get_shape(i)
		if def == null:
			continue

		if def.default_unlocked and not Game_State.is_inventory_shape_unlocked(def.id):
			Game_State.unlock_inventory_shape(def.id)


func _connect_signals() -> void:
	if train_button != null and not train_button.pressed.is_connected(_on_train_button_pressed):
		train_button.pressed.connect(_on_train_button_pressed)

	if upgrade_button != null and not upgrade_button.pressed.is_connected(_on_upgrade_button_pressed):
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)

	if locked_phase_button != null and not locked_phase_button.pressed.is_connected(_on_locked_phase_button_pressed):
		locked_phase_button.pressed.connect(_on_locked_phase_button_pressed)

	if not Game_State.changed.is_connected(_on_game_state_changed):
		Game_State.changed.connect(_on_game_state_changed)

	if meta_tree_screen != null:
		if not meta_tree_screen.closed.is_connected(_on_meta_tree_closed):
			meta_tree_screen.closed.connect(_on_meta_tree_closed)

		if not meta_tree_screen.shape_level_changed.is_connected(_on_meta_tree_shape_level_changed):
			meta_tree_screen.shape_level_changed.connect(_on_meta_tree_shape_level_changed)


func _build_slot_nodes() -> void:
	_slot_buttons.clear()

	for child in shape_grid.get_children():
		child.queue_free()

	if slot_scene == null:
		push_error("slot_scene is not assigned in Inventory inspector.")
		return

	for i in range(inventory_db.size()):
		var def: InventoryShapeDef = inventory_db.get_shape(i)
		if def == null:
			continue

		var raw_slot: Node = slot_scene.instantiate()
		var slot: InventoryShapeSlot = raw_slot as InventoryShapeSlot

		if slot == null:
			push_error("Failed to cast instantiated slot to InventoryShapeSlot.")
			continue

		if not slot.slot_pressed.is_connected(_on_slot_button_pressed):
			slot.slot_pressed.connect(_on_slot_button_pressed)

		shape_grid.add_child(slot)

		var tex: Texture2D = def.icon_texture if _is_shape_unlocked(def) else locked_icon
		slot.setup(i, tex, not _is_shape_unlocked(def))

		_slot_buttons.append(slot)


func _collect_level_boxes() -> void:
	_level_boxes.clear()
	for child in level_boxes_root.get_children():
		if child is TextureRect:
			_level_boxes.append(child)


func _refresh_energy_label() -> void:
	energy_label.text = "Converted: " + str(int(Game_State.converted_energy))


func _rebuild_visible_slots() -> void:
	if inventory_db == null:
		return

	if _slot_buttons.size() != inventory_db.size():
		_build_slot_nodes()
		return

	for i in range(_slot_buttons.size()):
		var slot: InventoryShapeSlot = _slot_buttons[i]
		var def: InventoryShapeDef = inventory_db.get_shape(i)

		if slot == null or def == null:
			continue

		var tex: Texture2D = def.icon_texture if _is_shape_unlocked(def) else locked_icon
		slot.setup(i, tex, not _is_shape_unlocked(def))


func _select_slot(index: int) -> void:
	if inventory_db == null or inventory_db.size() == 0:
		_show_locked_fallback()
		return

	if index < 0 or index >= inventory_db.size():
		_show_locked_fallback()
		return

	_selected_slot_index = index

	for i in range(_slot_buttons.size()):
		var slot: InventoryShapeSlot = _slot_buttons[i]
		if slot != null:
			slot.set_selected(i == index)

	var def: InventoryShapeDef = inventory_db.get_shape(index)
	if def == null:
		_show_locked_fallback()
		return

	if _is_shape_unlocked(def):
		_show_unlocked(def)
	else:
		_show_locked(def)


func _is_shape_unlocked(def: InventoryShapeDef) -> bool:
	if def == null:
		return false
	return Game_State.is_inventory_shape_unlocked(def.id)


func _show_unlocked(def: InventoryShapeDef) -> void:
	unlocked_panel.visible = true
	locked_panel.visible = false

	var shape_id: String = def.id.strip_edges().to_lower()

	# Player-facing level: internal 0 becomes UI level 1.
	var internal_level: int = Game_State.get_shape_level(shape_id)
	var display_level: int = internal_level + 1

	var shape_cores: int = Game_State.get_shape_cores(shape_id)

	level_label.text = "Level: %d" % display_level
	_update_level_boxes(def, display_level)
	currency_label.text = "Currency: %d" % shape_cores

	damage_value.text = _fmt_number(_get_scaled_damage(def, internal_level))
	attack_speed_value.text = _fmt_number(def.attack_speed)
	projectile_count_value.text = str(def.projectile_count)
	projectile_size_value.text = _fmt_number(def.projectile_size)
	crit_chance_value.text = _fmt_number(def.crit_chance)
	crit_damage_value.text = _fmt_number(def.crit_damage)

	if Game_State.is_shape_ability_1_unlocked(shape_id):
		ability1_name.text = def.passive_name
		ability1_description.text = def.passive_description
		ability1_damage.text = def.passive_damage_text
		ability1_cooldown.text = def.passive_cooldown_text
		ability1_type.text = "Ability 1"
	else:
		ability1_name.text = "Locked"
		ability1_description.text = "Unlocks at Level 4."
		ability1_damage.text = "--"
		ability1_cooldown.text = "--"
		ability1_type.text = "Locked"

	if Game_State.is_shape_ultimate_unlocked(shape_id):
		ability2_name.text = def.active_name
		ability2_description.text = def.active_description
		ability2_damage.text = def.active_damage_text
		ability2_cooldown.text = def.active_cooldown_text
		ability2_type.text = "Ultimate"
	else:
		ability2_name.text = "Locked"
		ability2_description.text = "Unlocks at Level 8."
		ability2_damage.text = "--"
		ability2_cooldown.text = "--"
		ability2_type.text = "Locked"

	train_button_label.text = "Train"
	upgrade_button_label.text = "Upgrade"

	train_button.disabled = false
	upgrade_button.disabled = false


func _show_locked(def: InventoryShapeDef) -> void:
	unlocked_panel.visible = false
	locked_panel.visible = true

	locked_title.text = "Locked"

	var phase_label: String = "Phase 1"
	if def != null and def.unlock_phase_label.strip_edges() != "":
		phase_label = def.unlock_phase_label

	locked_info.text = "This shape is still locked. Reach %s in gameplay to unlock it in inventory." % phase_label
	locked_phase_button_label.text = phase_label


func _show_locked_fallback() -> void:
	unlocked_panel.visible = false
	locked_panel.visible = true
	locked_title.text = "Locked"
	locked_info.text = "This shape is still locked."
	locked_phase_button_label.text = "Phase 1"
	_update_level_boxes(null, 0)


func _update_level_boxes(def: InventoryShapeDef, level: int) -> void:
	var tex: Texture2D = null

	if def != null:
		tex = def.icon_texture

	for i in range(_level_boxes.size()):
		var box: TextureRect = _level_boxes[i]
		if box == null:
			continue

		box.texture = tex

		if box.texture == null:
			box.texture = locked_icon

		box.modulate = Color(1, 1, 1, 1) if i < level else Color(1, 1, 1, 0.22)


func _get_scaled_damage(def: InventoryShapeDef, internal_shape_level: int) -> float:
	var bonus_per_level: float = 0.10
	return def.damage * (1.0 + (bonus_per_level * float(internal_shape_level)))


func _get_selected_shape_def() -> InventoryShapeDef:
	if inventory_db == null:
		return null

	if _selected_slot_index < 0 or _selected_slot_index >= inventory_db.size():
		return null

	return inventory_db.get_shape(_selected_slot_index)


func _get_meta_tree_def_for_shape(shape_id: String) -> ShapeMetaTreeDef:
	var key: String = shape_id.strip_edges().to_lower()
	if key == "":
		return null

	if not meta_tree_defs.has(key):
		return null

	var value = meta_tree_defs.get(key)
	if value is ShapeMetaTreeDef:
		return value

	return null


func _on_slot_button_pressed(index: int) -> void:
	_select_slot(index)


func _on_train_button_pressed() -> void:
	var def: InventoryShapeDef = _get_selected_shape_def()
	if def == null:
		return

	if def.training_scene.strip_edges() == "":
		push_warning("Training scene not set yet for shape: %s" % def.id)
		return

	if not ResourceLoader.exists(def.training_scene):
		push_warning("Training scene does not exist: %s" % def.training_scene)
		return

	get_tree().change_scene_to_file(def.training_scene)


func _on_upgrade_button_pressed() -> void:
	var def: InventoryShapeDef = _get_selected_shape_def()
	if def == null:
		print("UPGRADE: selected shape def is null")
		return

	print("UPGRADE: selected shape = ", def.id)

	if not _is_shape_unlocked(def):
		print("UPGRADE: shape is locked")
		return

	if meta_tree_screen == null:
		print("UPGRADE: MetaTreeScreen node is missing")
		push_warning("MetaTreeScreen node is missing from Inventory scene.")
		return

	print("UPGRADE: MetaTreeScreen found = ", meta_tree_screen.name)

	var tree_def: ShapeMetaTreeDef = _get_meta_tree_def_for_shape(def.id)
	if tree_def == null:
		print("UPGRADE: no ShapeMetaTreeDef for shape = ", def.id)
		push_warning("No ShapeMetaTreeDef assigned for shape: %s" % def.id)
		return

	print("UPGRADE: opening meta tree for = ", tree_def.shape_id)
	meta_tree_screen.open_for_shape(def, tree_def)
	print("UPGRADE: meta tree visible = ", meta_tree_screen.visible)


func _on_locked_phase_button_pressed() -> void:
	if phase1_scene.strip_edges() == "":
		return
	get_tree().change_scene_to_file(phase1_scene)


func _on_game_state_changed() -> void:
	_refresh_energy_label()
	_rebuild_visible_slots()

	if inventory_db != null and inventory_db.size() > 0:
		_selected_slot_index = clamp(_selected_slot_index, 0, inventory_db.size() - 1)
		_select_slot(_selected_slot_index)
	else:
		_show_locked_fallback()


func _on_meta_tree_closed() -> void:
	if inventory_db != null and inventory_db.size() > 0:
		_select_slot(_selected_slot_index)


func _on_meta_tree_shape_level_changed(shape_id: StringName, new_level: int) -> void:
	var def: InventoryShapeDef = _get_selected_shape_def()
	if def == null:
		return

	if def.id.strip_edges().to_lower() == str(shape_id).strip_edges().to_lower():
		_select_slot(_selected_slot_index)


func _fmt_number(value: float) -> String:
	if abs(value - round(value)) < 0.001:
		return str(int(round(value)))
	return "%0.2f" % value


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(menu_scene)


func _unhandled_input(event: InputEvent) -> void:
	if meta_tree_screen != null and meta_tree_screen.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(menu_scene)
