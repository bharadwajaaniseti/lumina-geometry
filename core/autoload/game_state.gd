extends Node
class_name GameState

signal changed

const SAVE_VERSION: int = 9

var stored_energy: float = 0.0
var total_energy_generated: float = 0.0
var converted_energy: float = 0.0
var cycle_count: int = 0
var alignment_multiplier: float = 1.0
var upgrades: Dictionary = {}

# Tracks which inventory shapes the player has unlocked/reached.
# Example:
# {
#   "circle": true,
#   "pyramid": true
# }
var unlocked_inventory_shapes: Dictionary = {}

const IDS := {
	"SPAWN_RATE": "SPAWN_RATE",
	"TIER2_CHANCE": "TIER2_CHANCE",
	"ROUND_TIME": "ROUND_TIME",
	"DEPOSIT_MULT": "DEPOSIT_MULT",
	"AUTO_INTERVAL": "AUTO_INTERVAL",
	"AUTO_RANGE": "AUTO_RANGE",
}

var _upgrade_defs: Dictionary = {}
var _always_run_requirements: Dictionary = {
	"ROUND_TIME": 40,
	"AUTO_INTERVAL": 48,
	"AUTO_RANGE": 10,
}

func _ensure_defs() -> void:
	if not _upgrade_defs.is_empty():
		return

	_upgrade_defs = {
		IDS.SPAWN_RATE: {
			"title": "Spawn Rate",
			"max_level": 15,
			"base_cost": 25.0,
			"cost_growth": 1.35,
			"bonus_per_level": 0.05,
		},
		IDS.TIER2_CHANCE: {
			"title": "Tier Boost",
			"max_level": 10,
			"base_cost": 30.0,
			"cost_growth": 1.35,
			"bonus_per_level": 0.02,
			"max_value": 0.20,
		},
		IDS.ROUND_TIME: {
			"title": "Time",
			"max_level": -1,
			"base_cost": 60.0,
			"cost_growth": 1.42,
			"bonus_per_level": 4.0,
		},
		IDS.DEPOSIT_MULT: {
			"title": "Multiplier",
			"max_level": -1,
			"base_cost": 50.0,
			"cost_growth": 1.42,
			"bonus_per_level": 0.03,
			"base_value": 1.0,
		},
		IDS.AUTO_INTERVAL: {
			"title": "Interval",
			"max_level": -1,
			"base_cost": 60.0,
			"cost_growth": 1.38,
			"level_factor": 0.90,
			"min_fraction": 0.01,
		},
		IDS.AUTO_RANGE: {
			"title": "Range",
			"max_level": 10,
			"base_cost": 50.0,
			"cost_growth": 1.38,
			"bonus_per_level": 1.0,
			"max_bonus": 10.0,
		},
	}

func configure_upgrade(id: String, config: Dictionary) -> void:
	_ensure_defs()

	var existing: Dictionary = _upgrade_defs.get(id, {}).duplicate(true)
	for key in config.keys():
		existing[key] = config[key]
	_upgrade_defs[id] = existing

func set_always_run_requirements(time_level: int, interval_level: int, range_level: int) -> void:
	_always_run_requirements["ROUND_TIME"] = max(time_level, 0)
	_always_run_requirements["AUTO_INTERVAL"] = max(interval_level, 0)
	_always_run_requirements["AUTO_RANGE"] = max(range_level, 0)

func get_upgrade_def(id: String) -> Dictionary:
	_ensure_defs()
	return _upgrade_defs.get(id, {}).duplicate(true)

func get_upgrade_title(id: String) -> String:
	_ensure_defs()
	return str(_upgrade_defs.get(id, {}).get("title", id))

func get_max_level(id: String) -> int:
	_ensure_defs()
	return int(_upgrade_defs.get(id, {}).get("max_level", -1))

func reset_to_defaults() -> void:
	stored_energy = 0.0
	total_energy_generated = 0.0
	converted_energy = 0.0
	cycle_count = 0
	upgrades = {}
	alignment_multiplier = 1.0
	unlocked_inventory_shapes = {}
	changed.emit()

func _to_float(value: Variant, default_value: float = 0.0) -> float:
	if value == null:
		return default_value

	match typeof(value):
		TYPE_FLOAT:
			return value
		TYPE_INT:
			return float(value)
		TYPE_STRING:
			return str(value).to_float()
		_:
			return str(value).to_float()

func _to_int(value: Variant, default_value: int = 0) -> int:
	if value == null:
		return default_value

	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			return str(value).to_int()
		_:
			return str(value).to_int()

func load_from_disk() -> void:
	var data: Dictionary = Save_Manager.load_game()
	if data.is_empty():
		reset_to_defaults()
		return

	var v: int = _to_int(data.get("version", 0), 0)
	if v <= 0:
		reset_to_defaults()
		return

	stored_energy = _to_float(data.get("stored_energy", 0.0), 0.0)
	total_energy_generated = _to_float(data.get("total_energy_generated", 0.0), 0.0)
	converted_energy = _to_float(data.get("converted_energy", 0.0), 0.0)
	cycle_count = _to_int(data.get("cycle_count", 0), 0)
	alignment_multiplier = _to_float(data.get("alignment_multiplier", 1.0), 1.0)

	upgrades = data.get("upgrades", {})
	if typeof(upgrades) != TYPE_DICTIONARY:
		upgrades = {}

	unlocked_inventory_shapes = data.get("unlocked_inventory_shapes", {})
	if typeof(unlocked_inventory_shapes) != TYPE_DICTIONARY:
		unlocked_inventory_shapes = {}

	changed.emit()

func save_to_disk() -> void:
	var data := {
		"version": SAVE_VERSION,
		"stored_energy": stored_energy,
		"total_energy_generated": total_energy_generated,
		"converted_energy": converted_energy,
		"cycle_count": cycle_count,
		"alignment_multiplier": alignment_multiplier,
		"upgrades": upgrades,
		"unlocked_inventory_shapes": unlocked_inventory_shapes,
	}
	Save_Manager.save_game(data)

func deposit_run_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	stored_energy += amount
	total_energy_generated += amount
	changed.emit()

func spend_stored(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if stored_energy < amount:
		return false
	stored_energy -= amount
	changed.emit()
	return true

func spend_converted(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if converted_energy < amount:
		return false
	converted_energy -= amount
	changed.emit()
	return true

func get_conversion_result_sqrt(reserved_amount: float, sqrt_multiplier: float = 1.0) -> int:
	if reserved_amount <= 0.0:
		return 0
	return int(floor(sqrt(reserved_amount) * sqrt_multiplier))

func get_conversion_result_ratio(reserved_amount: float, conversion_ratio: float = 0.001) -> int:
	if reserved_amount <= 0.0:
		return 0
	return int(floor(reserved_amount * conversion_ratio))

func consume_reserved_chunk(
	chunk_amount: float,
	conversion_mode: int = 0,
	conversion_ratio: float = 0.001,
	sqrt_multiplier: float = 1.0
) -> int:
	if stored_energy <= 0.0 or chunk_amount <= 0.0:
		return 0

	var before: float = stored_energy
	var spend: float = min(before, chunk_amount)
	var after: float = before - spend

	var before_score: int = 0
	var after_score: int = 0

	if conversion_mode == 1:
		before_score = get_conversion_result_ratio(before, conversion_ratio)
		after_score = get_conversion_result_ratio(after, conversion_ratio)
	else:
		before_score = get_conversion_result_sqrt(before, sqrt_multiplier)
		after_score = get_conversion_result_sqrt(after, sqrt_multiplier)

	var gained: int = before_score - after_score

	stored_energy = after
	changed.emit()

	return max(gained, 0)

func add_converted(amount: int) -> void:
	if amount <= 0:
		return
	converted_energy += amount
	changed.emit()

func increment_cycle() -> void:
	cycle_count += 1
	changed.emit()
	save_to_disk()

func always_run_unlocked() -> bool:
	return (
		get_level(IDS.ROUND_TIME) >= int(_always_run_requirements["ROUND_TIME"])
		and get_level(IDS.AUTO_INTERVAL) >= int(_always_run_requirements["AUTO_INTERVAL"])
		and get_level(IDS.AUTO_RANGE) >= int(_always_run_requirements["AUTO_RANGE"])
	)

func automation_unlocked() -> bool:
	return get_level(IDS.AUTO_INTERVAL) > 0

func get_level(id: String) -> int:
	return int(upgrades.get(id, 0))

func can_level_up(id: String) -> bool:
	var max_lvl: int = get_max_level(id)
	if max_lvl >= 0 and get_level(id) >= max_lvl:
		return false
	return true

func get_next_cost(id: String) -> float:
	_ensure_defs()
	var lvl: int = get_level(id)
	var def: Dictionary = _upgrade_defs.get(id, {})
	var base: float = float(def.get("base_cost", 10.0))
	var growth: float = float(def.get("cost_growth", 1.4))
	return base * pow(growth, float(lvl))

func try_buy_level(id: String) -> bool:
	if not can_level_up(id):
		return false

	var cost: float = get_next_cost(id)
	if stored_energy < cost:
		return false

	if not spend_stored(cost):
		return false

	upgrades[id] = get_level(id) + 1
	changed.emit()
	save_to_disk()
	return true

func spawn_speed_mult() -> float:
	_ensure_defs()
	var def: Dictionary = _upgrade_defs.get(IDS.SPAWN_RATE, {})
	var lvl: int = get_level(IDS.SPAWN_RATE)
	return 1.0 + float(def.get("bonus_per_level", 0.05)) * float(lvl)

func tier2_chance() -> float:
	_ensure_defs()
	var def: Dictionary = _upgrade_defs.get(IDS.TIER2_CHANCE, {})
	var lvl: int = get_level(IDS.TIER2_CHANCE)
	var value: float = float(def.get("bonus_per_level", 0.02)) * float(lvl)
	return clamp(value, 0.0, float(def.get("max_value", 0.20)))

func round_time_bonus_sec() -> float:
	_ensure_defs()
	var def: Dictionary = _upgrade_defs.get(IDS.ROUND_TIME, {})
	var lvl: int = get_level(IDS.ROUND_TIME)
	return float(def.get("bonus_per_level", 4.0)) * float(lvl)

func deposit_mult() -> float:
	_ensure_defs()
	var def: Dictionary = _upgrade_defs.get(IDS.DEPOSIT_MULT, {})
	var lvl: int = get_level(IDS.DEPOSIT_MULT)
	return float(def.get("base_value", 1.0)) + float(def.get("bonus_per_level", 0.03)) * float(lvl)

func auto_merge_interval(base_interval: float) -> float:
	_ensure_defs()
	var def: Dictionary = _upgrade_defs.get(IDS.AUTO_INTERVAL, {})
	var lvl: int = get_level(IDS.AUTO_INTERVAL)
	var factor: float = float(def.get("level_factor", 0.90))
	var min_fraction: float = float(def.get("min_fraction", 0.01))
	var interval: float = base_interval * pow(factor, float(lvl))
	return max(interval, base_interval * min_fraction)

func auto_merge_range_bonus_px() -> float:
	_ensure_defs()
	var def: Dictionary = _upgrade_defs.get(IDS.AUTO_RANGE, {})
	var lvl: int = get_level(IDS.AUTO_RANGE)
	var bonus: float = float(def.get("bonus_per_level", 1.0)) * float(lvl)
	return clamp(bonus, 0.0, float(def.get("max_bonus", 10.0)))

func get_current_value_text(
	id: String,
	lvl: int,
	base_round_duration_sec: float,
	base_auto_merge_interval_sec: float,
	base_auto_merge_range_px: float
) -> String:
	_ensure_defs()

	match id:
		IDS.SPAWN_RATE:
			var bonus_pct: float = (1.0 + float(_upgrade_defs[id].get("bonus_per_level", 0.05)) * float(lvl) - 1.0) * 100.0
			return "%0.0f%%" % bonus_pct

		IDS.TIER2_CHANCE:
			var tier_bonus: float = clamp(
				float(_upgrade_defs[id].get("bonus_per_level", 0.02)) * float(lvl),
				0.0,
				float(_upgrade_defs[id].get("max_value", 0.20))
			)
			return "%0.0f%%" % (tier_bonus * 100.0)

		IDS.ROUND_TIME:
			var t: float = base_round_duration_sec + float(_upgrade_defs[id].get("bonus_per_level", 4.0)) * float(lvl)
			return "%0.0fs" % t

		IDS.DEPOSIT_MULT:
			var mult: float = float(_upgrade_defs[id].get("base_value", 1.0)) + float(_upgrade_defs[id].get("bonus_per_level", 0.03)) * float(lvl)
			return "%0.2fx" % mult

		IDS.AUTO_INTERVAL:
			var factor: float = float(_upgrade_defs[id].get("level_factor", 0.90))
			var min_fraction: float = float(_upgrade_defs[id].get("min_fraction", 0.01))
			var interval: float = max(base_auto_merge_interval_sec * pow(factor, float(lvl)), base_auto_merge_interval_sec * min_fraction)
			return "%0.2fs" % interval

		IDS.AUTO_RANGE:
			var range_bonus: float = clamp(
				float(_upgrade_defs[id].get("bonus_per_level", 1.0)) * float(lvl),
				0.0,
				float(_upgrade_defs[id].get("max_bonus", 10.0))
			)
			return "%0.0fpx" % (base_auto_merge_range_px + range_bonus)

		_:
			return "0"

func get_next_value_text(
	id: String,
	lvl: int,
	base_round_duration_sec: float,
	base_auto_merge_interval_sec: float,
	base_auto_merge_range_px: float
) -> String:
	var max_lvl: int = get_max_level(id)
	if max_lvl >= 0 and lvl >= max_lvl:
		return get_current_value_text(id, lvl, base_round_duration_sec, base_auto_merge_interval_sec, base_auto_merge_range_px)

	return get_current_value_text(id, lvl + 1, base_round_duration_sec, base_auto_merge_interval_sec, base_auto_merge_range_px)

# -------------------------------------------------------------------
# Inventory shape unlock progression
# -------------------------------------------------------------------

func is_inventory_shape_unlocked(shape_id: String) -> bool:
	var key: String = shape_id.strip_edges().to_lower()
	if key == "":
		return false
	return bool(unlocked_inventory_shapes.get(key, false))

func unlock_inventory_shape(shape_id: String) -> void:
	var key: String = shape_id.strip_edges().to_lower()
	if key == "":
		return

	if bool(unlocked_inventory_shapes.get(key, false)):
		return

	unlocked_inventory_shapes[key] = true
	changed.emit()
	save_to_disk()

func lock_inventory_shape(shape_id: String) -> void:
	var key: String = shape_id.strip_edges().to_lower()
	if key == "":
		return

	if not bool(unlocked_inventory_shapes.get(key, false)):
		return

	unlocked_inventory_shapes.erase(key)
	changed.emit()
	save_to_disk()

func set_inventory_shape_unlocked(shape_id: String, unlocked: bool) -> void:
	if unlocked:
		unlock_inventory_shape(shape_id)
	else:
		lock_inventory_shape(shape_id)

func get_unlocked_inventory_shape_ids() -> Array[String]:
	var result: Array[String] = []
	for key in unlocked_inventory_shapes.keys():
		if bool(unlocked_inventory_shapes.get(key, false)):
			result.append(str(key))
	return result
