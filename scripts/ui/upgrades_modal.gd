extends Control

signal closed

## If true, the scene tree pauses while the modal is open.
## Example: true = gameplay stops behind the modal, false = gameplay keeps running.
@export var pause_game_when_open: bool = true

## Base round length used only for displaying Time upgrade values in this modal.
## Example: 120 means Time Lv 0 shows 120s before bonus levels are added.
@export var base_round_duration_sec: float = 120.0

## Base automation interval used only for displaying Interval upgrade values in this modal.
## Example: 1.5 means Interval Lv 0 shows 1.50s before reductions are applied.
@export var base_auto_merge_interval_sec: float = 1.5

## Base auto-merge range used only for displaying Range upgrade values in this modal.
## Example: 110 means Range Lv 0 shows 110px before bonus levels are added.
@export var base_auto_merge_range_px: float = 110.0

@export_group("Always-Run Unlock Thresholds")
## Required Time level for Always-Run mode.
## Example: 40 means Always-Run needs Time Lv 40.
@export var always_run_time_level: int = 40

## Required Interval level for Always-Run mode.
## Example: 48 means Always-Run needs Interval Lv 48.
@export var always_run_interval_level: int = 48

## Required Range level for Always-Run mode.
## Example: 10 means Always-Run needs Range Lv 10.
@export var always_run_range_level: int = 10

@export_group("Spawn Rate Upgrade")
## Maximum level for Spawn Rate.
## Use -1 for infinite levels.
## Example: 15 means the upgrade stops at Lv 15.
@export var spawn_rate_max_level: int = 15

## Base cost for Spawn Rate Lv 1.
## Example: 25 means the first purchase costs 25 reserve.
@export var spawn_rate_base_cost: float = 25.0

## Exponential cost growth for Spawn Rate.
## Example: 1.35 means each next level costs 35% more than the previous one.
@export var spawn_rate_cost_growth: float = 1.35

## Spawn speed bonus added per level.
## Example: 0.05 means +5% spawn speed per level.
@export var spawn_rate_bonus_per_level: float = 0.05

@export_group("Tier Boost Upgrade")
## Maximum level for Tier Boost.
## Use -1 for infinite levels.
@export var tier2_max_level: int = 10

## Base cost for Tier Boost Lv 1.
@export var tier2_base_cost: float = 30.0

## Exponential cost growth for Tier Boost.
@export var tier2_cost_growth: float = 1.35

## Extra direct Tier-2 spawn chance added per level.
## Example: 0.02 means +2% per level.
@export var tier2_bonus_per_level: float = 0.02

## Hard cap for Tier Boost chance.
## Example: 0.20 means the chance can never exceed 20%.
@export var tier2_max_value: float = 0.20

@export_group("Time Upgrade")
## Maximum level for Time.
## Use -1 for infinite levels.
@export var round_time_max_level: int = -1

## Base cost for Time Lv 1.
@export var round_time_base_cost: float = 60.0

## Exponential cost growth for Time.
@export var round_time_cost_growth: float = 1.42

## Seconds added to round duration per level.
## Example: 4 means each level adds +4 seconds.
@export var round_time_bonus_per_level: float = 4.0

@export_group("Multiplier Upgrade")
## Maximum level for Multiplier.
## Use -1 for infinite levels.
@export var deposit_mult_max_level: int = -1

## Base cost for Multiplier Lv 1.
@export var deposit_mult_base_cost: float = 50.0

## Exponential cost growth for Multiplier.
@export var deposit_mult_cost_growth: float = 1.42

## Base multiplier value before any levels.
## Example: 1.0 means no bonus at Lv 0.
@export var deposit_mult_base_value: float = 1.0

## Extra deposit multiplier added per level.
## Example: 0.03 means +0.03x per level.
@export var deposit_mult_bonus_per_level: float = 0.03

@export_group("Interval Upgrade")
## Maximum level for Interval.
## Use -1 for infinite levels.
@export var auto_interval_max_level: int = -1

## Base cost for Interval Lv 1.
@export var auto_interval_base_cost: float = 60.0

## Exponential cost growth for Interval.
@export var auto_interval_cost_growth: float = 1.38

## Reduction factor applied each level.
## Example: 0.90 means each level keeps 90% of the previous interval.
@export_range(0.01, 0.999, 0.001) var auto_interval_level_factor: float = 0.90

## Lowest allowed interval as a fraction of the base interval.
## Example: 0.01 with base 1.5s means minimum interval is 0.015s.
@export_range(0.001, 1.0, 0.001) var auto_interval_min_fraction: float = 0.01

@export_group("Range Upgrade")
## Maximum level for Range.
## Use -1 for infinite levels.
@export var auto_range_max_level: int = 10

## Base cost for Range Lv 1.
@export var auto_range_base_cost: float = 50.0

## Exponential cost growth for Range.
@export var auto_range_cost_growth: float = 1.38

## Range bonus in pixels added per level.
## Example: 1 means +1px per level.
@export var auto_range_bonus_per_level: float = 1.0

## Maximum total bonus range allowed.
## Example: 10 means the bonus part can never exceed +10px.
@export var auto_range_max_bonus: float = 10.0

@export_group("Upgrade Card Node Paths")
@export var spawn_item1_path: NodePath
@export var spawn_item2_path: NodePath
@export var time_item1_path: NodePath
@export var time_item2_path: NodePath
@export var auto_item1_path: NodePath
@export var auto_item2_path: NodePath

@onready var spawn_desc: Label = $Center/Card/Margin/VBox/Columns/SpawnCol/Pad/ColVbox/ColDesc
@onready var time_desc: Label = $Center/Card/Margin/VBox/Columns/TimeCol/Pad/ColVbox/ColDesc
@onready var auto_desc: Label = $Center/Card/Margin/VBox/Columns/AutoCol/Pad/ColVbox/ColDesc

@onready var dimmer: ColorRect = $Dimmer
@onready var card: Control = $Center/Card
@onready var close_btn: Button = $Center/Card/Margin/VBox/CloseBtn
@onready var stored_lbl: Label = $Center/Card/Margin/VBox/HeaderRow/Reserve

var _spawn_item1: Control
var _spawn_item2: Control
var _time_item1: Control
var _time_item2: Control
var _auto_item1: Control
var _auto_item2: Control

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_push_upgrade_config_to_game_state()
	_setup_column_descriptions()

	close_btn.pressed.connect(close)

	_spawn_item1 = get_node(spawn_item1_path) as Control
	_spawn_item2 = get_node(spawn_item2_path) as Control
	_time_item1 = get_node(time_item1_path) as Control
	_time_item2 = get_node(time_item2_path) as Control
	_auto_item1 = get_node(auto_item1_path) as Control
	_auto_item2 = get_node(auto_item2_path) as Control

	Game_State.changed.connect(_refresh)

	_setup_card_fx(_spawn_item1)
	_setup_card_fx(_spawn_item2)
	_setup_card_fx(_time_item1)
	_setup_card_fx(_time_item2)
	_setup_card_fx(_auto_item1)
	_setup_card_fx(_auto_item2)

	_bind_item(_spawn_item1, Game_State.IDS.SPAWN_RATE)
	_bind_item(_spawn_item2, Game_State.IDS.TIER2_CHANCE)
	_bind_item(_time_item1, Game_State.IDS.ROUND_TIME)
	_bind_item(_time_item2, Game_State.IDS.DEPOSIT_MULT)
	_bind_item(_auto_item1, Game_State.IDS.AUTO_INTERVAL)
	_bind_item(_auto_item2, Game_State.IDS.AUTO_RANGE)

func _push_upgrade_config_to_game_state() -> void:
	Game_State.configure_upgrade(Game_State.IDS.SPAWN_RATE, {
		"title": "Spawn Rate",
		"max_level": spawn_rate_max_level,
		"base_cost": spawn_rate_base_cost,
		"cost_growth": spawn_rate_cost_growth,
		"bonus_per_level": spawn_rate_bonus_per_level,
	})

	Game_State.configure_upgrade(Game_State.IDS.TIER2_CHANCE, {
		"title": "Tier Boost",
		"max_level": tier2_max_level,
		"base_cost": tier2_base_cost,
		"cost_growth": tier2_cost_growth,
		"bonus_per_level": tier2_bonus_per_level,
		"max_value": tier2_max_value,
	})

	Game_State.configure_upgrade(Game_State.IDS.ROUND_TIME, {
		"title": "Time",
		"max_level": round_time_max_level,
		"base_cost": round_time_base_cost,
		"cost_growth": round_time_cost_growth,
		"bonus_per_level": round_time_bonus_per_level,
	})

	Game_State.configure_upgrade(Game_State.IDS.DEPOSIT_MULT, {
		"title": "Multiplier",
		"max_level": deposit_mult_max_level,
		"base_cost": deposit_mult_base_cost,
		"cost_growth": deposit_mult_cost_growth,
		"base_value": deposit_mult_base_value,
		"bonus_per_level": deposit_mult_bonus_per_level,
	})

	Game_State.configure_upgrade(Game_State.IDS.AUTO_INTERVAL, {
		"title": "Interval",
		"max_level": auto_interval_max_level,
		"base_cost": auto_interval_base_cost,
		"cost_growth": auto_interval_cost_growth,
		"level_factor": auto_interval_level_factor,
		"min_fraction": auto_interval_min_fraction,
	})

	Game_State.configure_upgrade(Game_State.IDS.AUTO_RANGE, {
		"title": "Range",
		"max_level": auto_range_max_level,
		"base_cost": auto_range_base_cost,
		"cost_growth": auto_range_cost_growth,
		"bonus_per_level": auto_range_bonus_per_level,
		"max_bonus": auto_range_max_bonus,
	})

	Game_State.set_always_run_requirements(
		always_run_time_level,
		always_run_interval_level,
		always_run_range_level
	)

func _setup_column_descriptions() -> void:
	spawn_desc.text = "Adjust spawn probability and tier escalation parameters."
	time_desc.text = "Modify cycle duration and output amplification values."
	auto_desc.text = "Configure automation interval and merge detection range."

func open() -> void:
	_refresh()

	dimmer.modulate.a = 0.0
	card.modulate.a = 0.0
	card.scale = Vector2(0.94, 0.94)

	visible = true
	if pause_game_when_open:
		get_tree().paused = true

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(dimmer, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not visible:
		return

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(dimmer, "modulate:a", 0.0, 0.10)
	tw.parallel().tween_property(card, "modulate:a", 0.0, 0.10)
	tw.parallel().tween_property(card, "scale", Vector2(0.96, 0.96), 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tw.finished.connect(func():
		visible = false
		if pause_game_when_open:
			get_tree().paused = false
		closed.emit()
	)

func _setup_card_fx(card_node: Control) -> void:
	if card_node == null:
		return

	if not card_node.mouse_entered.is_connected(Callable(self, "_on_card_mouse_entered").bind(card_node)):
		card_node.mouse_entered.connect(_on_card_mouse_entered.bind(card_node))
	if not card_node.mouse_exited.is_connected(Callable(self, "_on_card_mouse_exited").bind(card_node)):
		card_node.mouse_exited.connect(_on_card_mouse_exited.bind(card_node))

	var glow := card_node.get_node_or_null("Glow") as ColorRect
	if glow != null:
		glow.modulate.a = 0.0

func _on_card_mouse_entered(card_node: Control) -> void:
	_set_glow(card_node, 0.16)

func _on_card_mouse_exited(card_node: Control) -> void:
	_set_glow(card_node, 0.0)

func _set_glow(card_node: Control, a: float) -> void:
	var glow := card_node.get_node_or_null("Glow") as ColorRect
	if glow == null:
		return

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(glow, "modulate:a", a, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _pop_card(card_node: Control) -> void:
	if card_node == null:
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card_node.scale = Vector2.ONE
	tw.tween_property(card_node, "scale", Vector2(1.03, 1.03), 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_node, "scale", Vector2.ONE, 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _flash_reserve() -> void:
	if stored_lbl == null:
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	stored_lbl.scale = Vector2.ONE
	var base := stored_lbl.self_modulate
	var hot := Color(1.0, 0.45, 0.45, 1.0)

	tw.tween_property(stored_lbl, "self_modulate", hot, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(stored_lbl, "scale", Vector2(1.04, 1.04), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stored_lbl, "self_modulate", base, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(stored_lbl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _bind_item(item: Control, id: String) -> void:
	var buy_btn: Button = _apply_btn(item)
	if buy_btn == null:
		push_error("UpgradesModal: Missing Apply button in %s" % item.name)
		return

	buy_btn.pressed.connect(func() -> void:
		if not Game_State.can_level_up(id):
			_pop_card(item)
			return

		var cost: float = Game_State.get_next_cost(id)
		if Game_State.stored_energy < cost:
			_flash_reserve()
			_shake_card(item)
			return

		var ok: bool = Game_State.try_buy_level(id)
		if ok:
			_pop_card(item)
		else:
			_shake_card(item)
	)

func _shake_card(card_node: Control) -> void:
	if card_node == null:
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var x0 := card_node.position
	tw.tween_property(card_node, "position", x0 + Vector2(6, 0), 0.05)
	tw.tween_property(card_node, "position", x0 + Vector2(-6, 0), 0.05)
	tw.tween_property(card_node, "position", x0 + Vector2(3, 0), 0.05)
	tw.tween_property(card_node, "position", x0, 0.05)

func _apply_btn(item: Control) -> Button:
	return item.get_node_or_null("Content/VBox/Apply") as Button

func _name_lbl(item: Control) -> Label:
	return item.get_node_or_null("Content/VBox/Name") as Label

func _value_lbl(item: Control) -> Label:
	return item.get_node_or_null("Content/VBox/Value") as Label

func _refresh() -> void:
	stored_lbl.text = "Reserve: %d" % int(roundi(Game_State.stored_energy))

	_refresh_item(_spawn_item1, Game_State.IDS.SPAWN_RATE)
	_refresh_item(_spawn_item2, Game_State.IDS.TIER2_CHANCE)
	_refresh_item(_time_item1, Game_State.IDS.ROUND_TIME)
	_refresh_item(_time_item2, Game_State.IDS.DEPOSIT_MULT)
	_refresh_item(_auto_item1, Game_State.IDS.AUTO_INTERVAL)
	_refresh_item(_auto_item2, Game_State.IDS.AUTO_RANGE)

func _refresh_item(item: Control, id: String) -> void:
	var name_lbl: Label = _name_lbl(item)
	var value_lbl: Label = _value_lbl(item)
	var buy_btn: Button = _apply_btn(item)

	if name_lbl == null or value_lbl == null or buy_btn == null:
		push_error("UpgradesModal: Card '%s' missing Name/Value/Apply under Content/VBox" % item.name)
		return

	var lvl: int = Game_State.get_level(id)
	var max_lvl: int = Game_State.get_max_level(id)

	name_lbl.text = Game_State.get_upgrade_title(id) + _level_text(lvl, max_lvl)

	var cur_txt: String = Game_State.get_current_value_text(
		id,
		lvl,
		base_round_duration_sec,
		base_auto_merge_interval_sec,
		base_auto_merge_range_px
	)
	var next_txt: String = Game_State.get_next_value_text(
		id,
		lvl,
		base_round_duration_sec,
		base_auto_merge_interval_sec,
		base_auto_merge_range_px
	)
	value_lbl.text = "%s → %s" % [cur_txt, next_txt]

	if not Game_State.can_level_up(id):
		buy_btn.text = "MAX"
		buy_btn.disabled = true
		item.modulate.a = 0.75
		return

	var cost: float = Game_State.get_next_cost(id)
	buy_btn.text = "APPLY : %d" % int(roundi(cost))
	buy_btn.disabled = Game_State.stored_energy < cost
	item.modulate.a = 1.0 if not buy_btn.disabled else 0.85

func _level_text(lvl: int, max_lvl: int) -> String:
	if max_lvl < 0:
		return "  Lv %d" % lvl
	return "  Lv %d/%d" % [lvl, max_lvl]
