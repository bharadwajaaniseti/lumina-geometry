extends Control

@export var menu_scene: String = "res://scenes/menu/Menu.tscn"
@export var phase1_scene: String = "res://scenes/gameplay/phase_1/Phase1.tscn"

@export var inventory_db: InventoryShapeDB
@export var locked_icon: Texture2D

var _selected_slot_index: int = 0

var _slot_buttons: Array[TextureButton] = []
var _slot_icons: Array[TextureRect] = []
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


func _ready() -> void:
	if inventory_db == null:
		push_error("Inventory DB is not assigned on Inventory scene.")
		return

	_collect_slot_nodes()
	_collect_level_boxes()
	_apply_default_unlocks()
	_connect_signals()
	_refresh_energy_label()
	_rebuild_visible_slots()

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
	for i in range(_slot_buttons.size()):
		var btn: TextureButton = _slot_buttons[i]
		btn.toggle_mode = true
		if not btn.pressed.is_connected(_on_slot_button_pressed.bind(i)):
			btn.pressed.connect(_on_slot_button_pressed.bind(i))

	if train_button != null and not train_button.pressed.is_connected(_on_train_button_pressed):
		train_button.pressed.connect(_on_train_button_pressed)

	if upgrade_button != null and not upgrade_button.pressed.is_connected(_on_upgrade_button_pressed):
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)

	if locked_phase_button != null and not locked_phase_button.pressed.is_connected(_on_locked_phase_button_pressed):
		locked_phase_button.pressed.connect(_on_locked_phase_button_pressed)

	if not Game_State.changed.is_connected(_on_game_state_changed):
		Game_State.changed.connect(_on_game_state_changed)


func _collect_slot_nodes() -> void:
	_slot_buttons.clear()
	_slot_icons.clear()

	for child in shape_grid.get_children():
		if child is TextureButton:
			var btn := child as TextureButton
			_slot_buttons.append(btn)

			var icon: TextureRect = null
			for sub in btn.get_children():
				if sub is TextureRect:
					icon = sub
					break
			_slot_icons.append(icon)


func _collect_level_boxes() -> void:
	_level_boxes.clear()
	for child in level_boxes_root.get_children():
		if child is TextureRect:
			_level_boxes.append(child)


func _refresh_energy_label() -> void:
	energy_label.text = "Energy: %d" % int(floor(Game_State.stored_energy))


func _rebuild_visible_slots() -> void:
	var db_count: int = inventory_db.size()
	var slot_count: int = _slot_buttons.size()

	if db_count > slot_count:
		push_warning("Inventory DB has %d shapes but only %d slot buttons exist in scene." % [db_count, slot_count])

	for i in range(slot_count):
		var btn: TextureButton = _slot_buttons[i]
		var icon: TextureRect = _slot_icons[i]

		if i < db_count:
			btn.visible = true
			btn.disabled = false

			var def: InventoryShapeDef = inventory_db.get_shape(i)
			if def != null and icon != null:
				if _is_shape_unlocked(def):
					icon.texture = def.icon_texture
				else:
					icon.texture = locked_icon
				icon.modulate = Color(1, 1, 1, 1)
		else:
			btn.visible = false
			btn.disabled = true
			btn.button_pressed = false


func _select_slot(index: int) -> void:
	if inventory_db == null or inventory_db.size() == 0:
		_show_locked_fallback()
		return

	if index < 0 or index >= inventory_db.size():
		_show_locked_fallback()
		return

	_selected_slot_index = index

	for i in range(_slot_buttons.size()):
		var btn: TextureButton = _slot_buttons[i]
		if not btn.visible:
			btn.button_pressed = false
		else:
			btn.button_pressed = (i == index)

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

	level_label.text = "Level:"
	_update_level_boxes(def, 0)
	currency_label.text = "Currency: 0"

	damage_value.text = _fmt_number(def.damage)
	attack_speed_value.text = _fmt_number(def.attack_speed)
	projectile_count_value.text = str(def.projectile_count)
	projectile_size_value.text = _fmt_number(def.projectile_size)
	crit_chance_value.text = _fmt_number(def.crit_chance)
	crit_damage_value.text = _fmt_number(def.crit_damage)

	ability1_name.text = def.passive_name
	ability1_description.text = def.passive_description
	ability1_damage.text = def.passive_damage_text
	ability1_cooldown.text = def.passive_cooldown_text
	ability1_type.text = "Passive"

	ability2_name.text = def.active_name
	ability2_description.text = def.active_description
	ability2_damage.text = def.active_damage_text
	ability2_cooldown.text = def.active_cooldown_text
	ability2_type.text = "Active"

	train_button_label.text = "Train"
	upgrade_button_label.text = "Upgrade"

	train_button.disabled = true
	upgrade_button.disabled = true


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

		# Optional fallback if texture is missing
		if box.texture == null:
			box.texture = locked_icon

		# Highlight based on current level
		box.modulate = Color(1, 1, 1, 1) if i < level else Color(1, 1, 1, 0.22)

func _on_slot_button_pressed(index: int) -> void:
	if index < 0 or index >= inventory_db.size():
		return
	_select_slot(index)


func _on_train_button_pressed() -> void:
	pass


func _on_upgrade_button_pressed() -> void:
	pass


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


func _fmt_number(value: float) -> String:
	if abs(value - round(value)) < 0.001:
		return str(int(round(value)))
	return "%0.2f" % value


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(menu_scene)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(menu_scene)
