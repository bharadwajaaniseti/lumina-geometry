extends Resource
class_name InventoryShapeDef

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export var icon_texture: Texture2D
@export var default_unlocked: bool = false
@export var unlock_phase_label: String = "Phase 1"

@export_group("Scene Routing")
@export_file("*.tscn") var training_scene: String = ""
@export_file("*.tscn") var upgrade_scene: String = ""

@export_group("Training")
@export var base_train_cost: int = 50
@export var train_cost_step: int = 25
@export var train_currency_gain: int = 25

@export_group("Upgrade")
@export var base_upgrade_cost: int = 100
@export var upgrade_cost_step: int = 40

@export_group("Base Stats")
@export var damage: float = 0.0
@export var attack_speed: float = 0.0
@export var projectile_count: int = 0
@export var projectile_size: float = 0.0
@export var crit_chance: float = 0.0
@export var crit_damage: float = 0.0

@export_group("Passive Ability")
@export_multiline var passive_description: String = ""
@export var passive_name: String = ""
@export var passive_damage_text: String = ""
@export var passive_cooldown_text: String = ""

@export_group("Active Ability")
@export_multiline var active_description: String = ""
@export var active_name: String = ""
@export var active_damage_text: String = ""
@export var active_cooldown_text: String = ""

func get_train_cost(level: int) -> int:
	return base_train_cost + max(level, 0) * train_cost_step

func get_upgrade_cost(upgrade_tier: int) -> int:
	return base_upgrade_cost + max(upgrade_tier, 0) * upgrade_cost_step

func has_training_scene() -> bool:
	return training_scene.strip_edges() != ""

func has_upgrade_scene() -> bool:
	return upgrade_scene.strip_edges() != ""

func get_stats_dict() -> Dictionary:
	return {
		"damage": damage,
		"attack_speed": attack_speed,
		"projectile_count": projectile_count,
		"projectile_size": projectile_size,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage
	}

func get_passive_dict() -> Dictionary:
	return {
		"name": passive_name,
		"description": passive_description,
		"damage": passive_damage_text,
		"cooldown": passive_cooldown_text,
		"type": "Passive"
	}

func get_active_dict() -> Dictionary:
	return {
		"name": active_name,
		"description": active_description,
		"damage": active_damage_text,
		"cooldown": active_cooldown_text,
		"type": "Active"
	}
