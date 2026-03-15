extends Resource
class_name MetaUpgradeNodeDef

@export var id: StringName
@export var title: String = ""
@export_multiline var description: String = ""

@export var max_rank: int = 3
@export var base_cost_cores: int = 10
@export var cost_per_rank: int = 0

@export var stat_key: StringName
@export var base_value: float = 0.0
@export var value_per_rank: float = 0.0

@export var required_node_ids: Array[StringName] = []
@export var highlight_border: bool = false
