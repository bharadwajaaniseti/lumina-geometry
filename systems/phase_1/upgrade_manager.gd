extends Node
class_name UpgradeManager

enum UpgradeId { SPAWN_RATE, CAPACITY, MERGE_BURST }

# Levels reset per run
var spawn_rate_level: int = 0
var capacity_level: int = 0
var merge_burst_level: int = 0

# Base costs (tune later)
@export var spawn_rate_base_cost: float = 50.0
@export var capacity_base_cost: float = 80.0
@export var merge_burst_base_cost: float = 65.0

# Cost scaling
@export var cost_growth: float = 1.13

func reset_run() -> void:
	spawn_rate_level = 0
	capacity_level = 0
	merge_burst_level = 0

func get_level(id: int) -> int:
	match id:
		UpgradeId.SPAWN_RATE: return spawn_rate_level
		UpgradeId.CAPACITY: return capacity_level
		UpgradeId.MERGE_BURST: return merge_burst_level
		_: return 0

func get_cost(id: int) -> float:
	var lvl: int = get_level(id)
	var base: float = 0.0
	match id:
		UpgradeId.SPAWN_RATE: base = spawn_rate_base_cost
		UpgradeId.CAPACITY: base = capacity_base_cost
		UpgradeId.MERGE_BURST: base = merge_burst_base_cost
		_: base = 999999.0
	return base * pow(cost_growth, float(lvl))

func buy(id: int) -> void:
	# assumes affordability checked outside
	match id:
		UpgradeId.SPAWN_RATE:
			spawn_rate_level += 1
		UpgradeId.CAPACITY:
			capacity_level += 1
		UpgradeId.MERGE_BURST:
			merge_burst_level += 1

# -------------------------
# Effects (applied to systems)
# -------------------------
func apply_to_spawner(spawner: Spawner) -> void:
	if spawner == null:
		return

	# Spawn interval gets faster with level (diminishing returns)
	# interval = base / (1 + k*level)
	var base_interval: float = spawner.base_spawn_interval
	spawner.spawn_interval = base_interval / (1.0 + 0.06 * float(spawn_rate_level))

	# Capacity: +5 per level
	spawner.capacity_bonus = capacity_level * 5

func apply_to_economy(economy: Economy) -> void:
	if economy == null:
		return

	# Merge burst multiplier
	economy.merge_bonus_mult = 1.0 + 0.12 * float(merge_burst_level)
