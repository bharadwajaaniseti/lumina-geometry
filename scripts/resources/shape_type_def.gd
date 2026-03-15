extends Resource
class_name ShapeTypeDef

@export var id: StringName = &"circle"
@export var display_name: String = "Circle"
@export var merge_value: float = 1.0
@export var textures_by_color_rank: Array[Texture2D] = []
@export var vfx_colors_by_rank: Array[Color] = []

func colors_count() -> int:
	return textures_by_color_rank.size()
