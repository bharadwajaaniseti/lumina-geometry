extends Node
class_name Economy

@export var shape_db: ShapeDB

@export var starting_energy: float = 0.0
@export var max_energy: float = 999999999.0

## Passive energy per second before run multiplier.
@export var base_eps: float = 0.0

## Fallback reward if shape_db is missing or merge values are unavailable.
@export var merge_energy_base: float = 1.0

## Fallback scaling if shape_db is missing.
@export var merge_energy_tier_factor: float = 1.20

var _energy: float = 0.0
var _eps_bonus: float = 0.0
var _run_multiplier: float = 1.0

# ===== Round stats tracking =====
var merge_counts: Dictionary = {}
var energy_by_tier: Dictionary = {}
var total_merge_energy_this_round: float = 0.0

func reset_for_new_round() -> void:
	_energy = starting_energy
	_eps_bonus = 0.0
	_run_multiplier = 1.0
	reset_round_stats()

func get_run_multiplier() -> float:
	return _run_multiplier

func add_run_multiplier(delta: float) -> void:
	_run_multiplier = clamp(_run_multiplier + delta, 1.0, 9999.0)

func reset_round_stats() -> void:
	merge_counts.clear()
	energy_by_tier.clear()
	total_merge_energy_this_round = 0.0

func tick(delta: float) -> void:
	var gain: float = get_eps() * delta
	if gain > 0.0:
		add_energy(gain * _run_multiplier)

func get_eps() -> float:
	return base_eps + _eps_bonus

func add_eps_bonus(amount: float) -> void:
	_eps_bonus += amount

func get_energy() -> float:
	return _energy

func add_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	_energy = min(_energy + amount, max_energy)

func can_afford(cost: float) -> bool:
	return _energy >= cost

func spend(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if _energy < cost:
		return false
	_energy -= cost
	return true

## Removes and returns all currently stored run/cycle energy.
## Used by Runtime auto-banking when Always-Run is unlocked.
func extract_all_energy() -> float:
	if _energy <= 0.0:
		return 0.0
	var amount: float = _energy
	_energy = 0.0
	return amount

## Removes up to `amount` from live run energy and returns how much was actually removed.
func extract_energy(amount: float) -> float:
	if amount <= 0.0 or _energy <= 0.0:
		return 0.0
	var take: float = min(amount, _energy)
	_energy -= take
	return take

# Called by board.gd on merge
func on_merge(shape_type_index: int, color_rank: int, tier: int) -> void:
	var reward: float = 0.0

	if shape_db != null and shape_db.has_method("get_merge_value"):
		reward = shape_db.get_merge_value(shape_type_index, color_rank)
	else:
		var t: int = max(1, tier)
		reward = merge_energy_base * pow(merge_energy_tier_factor, float(t - 1))

	reward *= _run_multiplier
	add_energy(reward)
	_record_merge(tier, reward)

func _record_merge(tier: int, reward: float) -> void:
	merge_counts[tier] = int(merge_counts.get(tier, 0)) + 1
	energy_by_tier[tier] = float(energy_by_tier.get(tier, 0.0)) + reward
	total_merge_energy_this_round += reward

func build_round_summary() -> Dictionary:
	var rows: Array = []

	var tiers: Array = merge_counts.keys()
	tiers.sort()

	for k: Variant in tiers:
		var tier: int = int(k)
		var merged: int = int(merge_counts[tier])
		if merged <= 0:
			continue

		var e: float = float(energy_by_tier.get(tier, 0.0))

		rows.append({
			"tier": tier,
			"merged": merged,
			"energy": e
		})

	return {
		"rows": rows,
		"total_energy": int(round(total_merge_energy_this_round))
	}
