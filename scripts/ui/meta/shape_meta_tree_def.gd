extends Resource
class_name ShapeMetaTreeDef

@export var shape_id: StringName
@export var columns: int = 10

# Reserved for later if you want tree-defined level thresholds.
# Current implementation uses Game_State progression points for level.
@export var level_thresholds: Array[int] = [4, 10, 18]

@export var nodes: Array[MetaUpgradeNodeDef] = []
