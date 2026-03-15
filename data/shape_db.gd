@tool
extends Resource
class_name ShapeDB

@export var colors_per_shape: int = 10
@export var shape_types: Array = [] # Array of Resource-backed ShapeTypeDef entries

@export var color_rank_names: Array[String] = [
	"Orange", "Green", "Blue", "Purple", "Pink", "Cyan", "Yellow", "White", "Black", "Red"
]

@export var color_rank_palette: Array[Color] = [
	Color(1.00, 0.55, 0.15, 1.0),
	Color(0.20, 0.90, 0.35, 1.0),
	Color(0.25, 0.55, 1.00, 1.0),
	Color(0.62, 0.35, 1.00, 1.0),
	Color(1.00, 0.35, 0.70, 1.0),
	Color(0.20, 0.90, 0.95, 1.0),
	Color(1.00, 0.95, 0.20, 1.0),
	Color(1.00, 1.00, 1.00, 1.0),
	Color(0.10, 0.10, 0.10, 1.0),
	Color(1.00, 0.20, 0.20, 1.0)
]

@export var editor_build_shape_types_from_legacy: bool = false:
	set(value):
		editor_build_shape_types_from_legacy = value
		if Engine.is_editor_hint() and value:
			build_shape_types_from_legacy()
			editor_build_shape_types_from_legacy = false
			emit_changed()

@export var editor_rebuild_legacy: bool = false:
	set(value):
		editor_rebuild_legacy = value
		if Engine.is_editor_hint() and value:
			rebuild_legacy_from_shape_types()
			editor_rebuild_legacy = false
			emit_changed()

@export var tier_textures: Array[Texture2D] = []
@export var tier_vfx_colors: Array[Color] = []

func _get_shape_def(shape_type_index: int) -> Variant:
	if shape_type_index < 0 or shape_type_index >= shape_types.size():
		return null
	return shape_types[shape_type_index]
	
func _read_float_property(obj: Variant, property_name: String, default_value: float = 0.0) -> float:
	if obj == null:
		return default_value

	var raw_value: Variant = null

	if obj is Object:
		raw_value = obj.get(property_name)
	else:
		return default_value

	match typeof(raw_value):
		TYPE_FLOAT:
			return raw_value
		TYPE_INT:
			return float(raw_value)
		TYPE_STRING:
			return str(raw_value).to_float()
		_:
			return default_value

func _legacy_global_index(shape_type_index: int, color_rank: int) -> int:
	var cps: int = max(colors_per_shape, 1)
	return (shape_type_index * cps) + color_rank

func get_texture(shape_type_index: int, color_rank: int) -> Texture2D:
	var def = _get_shape_def(shape_type_index)
	if def == null:
		return null

	var textures_var: Variant = null
	if def is Object:
		textures_var = def.get("textures_by_color_rank")

	if typeof(textures_var) != TYPE_ARRAY:
		var legacy_index: int = _legacy_global_index(shape_type_index, color_rank)
		if legacy_index >= 0 and legacy_index < tier_textures.size():
			return tier_textures[legacy_index]
		return null

	var textures: Array = textures_var as Array
	if textures.is_empty():
		var legacy_index: int = _legacy_global_index(shape_type_index, color_rank)
		if legacy_index >= 0 and legacy_index < tier_textures.size():
			return tier_textures[legacy_index]
		return null

	if color_rank < 0 or color_rank >= textures.size():
		return null

	return textures[color_rank] as Texture2D

func get_vfx_color(shape_type_index: int, color_rank: int) -> Color:
	var def = _get_shape_def(shape_type_index)
	if def == null:
		return Color.WHITE

	var colors_var: Variant = null
	if def is Object:
		colors_var = def.get("vfx_colors_by_rank")

	if typeof(colors_var) != TYPE_ARRAY:
		return _palette_color(color_rank)

	var colors: Array = colors_var as Array
	if colors.is_empty():
		return _palette_color(color_rank)

	if color_rank < 0 or color_rank >= colors.size():
		var safe_index: int = clamp(color_rank, 0, colors.size() - 1)
		return colors[safe_index] as Color

	return colors[color_rank] as Color

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
			return default_value

func get_merge_value(shape_type_index: int, color_rank: int) -> float:
	var def = _get_shape_def(shape_type_index)
	var base_value: float = 0.0

	if def != null:
		base_value = _read_float_property(def, "merge_value", 0.0)

	if base_value <= 0.0:
		base_value = pow(10.0, float(max(shape_type_index, 0)))

	base_value = max(base_value, 0.0)

	return base_value * float(color_rank + 1)

func get_global_tier(shape_type_index: int, color_rank: int) -> int:
	return (shape_type_index * max(colors_per_shape, 1)) + color_rank + 1

func decode_global_tier(tier_1_based: int) -> Dictionary:
	var t: int = max(tier_1_based, 1) - 1
	var cps: int = max(colors_per_shape, 1)
	return {
		"shape_type": int(floor(float(t) / float(cps))),
		"color_rank": int(t % cps),
	}

func get_color_rank_name(color_rank: int) -> String:
	if color_rank >= 0 and color_rank < color_rank_names.size():
		return color_rank_names[color_rank]
	return "Rank %d" % color_rank

func build_shape_types_from_legacy() -> void:
	var cps: int = max(colors_per_shape, 1)
	var new_shape_types: Array = []

	for i in range(tier_textures.size()):
		var tex: Texture2D = tier_textures[i]
		if tex == null:
			continue

		var def := ShapeTypeDef.new()

		var disp: String = _name_from_texture(tex)
		def.display_name = disp
		def.id = StringName(_id_from_display_name(disp))
		def.merge_value = 1.0

		var tex_ranks: Array[Texture2D] = []
		tex_ranks.resize(cps)
		for r in range(cps):
			tex_ranks[r] = tex

		var vfx_ranks: Array[Color] = []
		vfx_ranks.resize(cps)
		for r in range(cps):
			vfx_ranks[r] = _palette_color(r)

		def.textures_by_color_rank = tex_ranks
		def.vfx_colors_by_rank = vfx_ranks

		new_shape_types.append(def)

	shape_types = new_shape_types

	emit_changed()
	if Engine.is_editor_hint():
		notify_property_list_changed()

func rebuild_legacy_from_shape_types() -> void:
	var cps: int = max(colors_per_shape, 1)

	var new_tier_textures: Array[Texture2D] = []
	var new_tier_vfx: Array[Color] = []

	for st_i in range(shape_types.size()):
		var def := shape_types[st_i] as Resource
		if def == null:
			continue

		var textures_var: Variant = def.get("textures_by_color_rank")
		var colors_var: Variant = def.get("vfx_colors_by_rank")

		var textures: Array = []
		var colors: Array = []

		if typeof(textures_var) == TYPE_ARRAY:
			textures = textures_var as Array
		if typeof(colors_var) == TYPE_ARRAY:
			colors = colors_var as Array

		for r in range(cps):
			var tex: Texture2D = null
			if r < textures.size():
				tex = textures[r] as Texture2D
			new_tier_textures.append(tex)

			var c: Color = _palette_color(r)
			if r < colors.size():
				c = colors[r] as Color
			new_tier_vfx.append(c)

	tier_textures = new_tier_textures
	tier_vfx_colors = new_tier_vfx

	emit_changed()
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _palette_color(rank: int) -> Color:
	if color_rank_palette.is_empty():
		return Color.WHITE
	var r: int = clamp(rank, 0, color_rank_palette.size() - 1)
	return color_rank_palette[r]

func _name_from_texture(tex: Texture2D) -> String:
	var p: String = tex.resource_path
	if p.is_empty():
		return "Shape"

	var base: String = p.get_file().get_basename()
	base = base.strip_edges()

	if base.begins_with("T1 "):
		base = base.substr(3, base.length() - 3)

	return base

func _id_from_display_name(name: String) -> String:
	var id := name.strip_edges().to_lower()
	id = id.replace(" ", "_")
	id = id.replace("-", "_")
	return id
