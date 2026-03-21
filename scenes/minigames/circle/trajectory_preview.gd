extends Node3D

@export_group("Visuals")
## Number of sampled points used to build the preview arc. Higher = smoother.
@export_range(4, 64, 1) var segment_count: int = 24
## Base width of the arc ribbon.
@export_range(0.001, 2.0, 0.001) var arc_width: float = 0.07
## Small lift above the board to avoid clipping.
@export_range(0.0, 1.0, 0.001) var y_offset: float = 0.03
## Default arc color.
@export var arc_color: Color = Color(0.18, 0.83, 0.78, 0.85)
## Default landing marker color.
@export var landing_color: Color = Color(0.18, 0.83, 0.78, 0.95)
## Gold highlight color when the landing would score.
@export var scoring_color: Color = Color(1.0, 0.84, 0.2, 1.0)

## Radius of the landing marker ring/puck.
@export_range(0.01, 5.0, 0.01) var landing_radius: float = 0.14
## Height of the landing marker.
@export_range(0.001, 1.0, 0.001) var landing_height: float = 0.012

@export_group("Style")
## Extra width added near the middle of the arc.
@export_range(0.0, 3.0, 0.01) var center_width_boost: float = 0.45
## Alpha near the arc ends.
@export_range(0.0, 1.0, 0.01) var end_alpha: float = 0.15
## Alpha near the middle of the arc.
@export_range(0.0, 1.0, 0.01) var center_alpha: float = 0.9

## Small breathing motion while active.
@export_range(0.0, 0.2, 0.001) var float_amplitude: float = 0.01
## Speed of breathing motion.
@export_range(0.0, 10.0, 0.01) var float_speed: float = 2.4

@export_group("Dash Pattern")
## Number of ribbon segments to draw before making a gap.
@export_range(1, 16, 1) var dash_draw_segments: int = 2
## Number of ribbon segments to skip for each gap.
@export_range(0, 16, 1) var dash_gap_segments: int = 1
## If true, the very end segment is always drawn so the landing reads clearly.
@export var always_draw_last_dash: bool = true

@export_group("Animation")
## How quickly the preview fades/scales in.
@export_range(0.0, 100.0, 0.1) var fade_in_speed: float = 12.0
## How quickly the preview fades/scales out.
@export_range(0.0, 100.0, 0.1) var fade_out_speed: float = 14.0
## Full visible scale.
@export var shown_scale: Vector3 = Vector3.ONE
## Collapsed scale when hidden.
@export var hidden_scale: Vector3 = Vector3(0.88, 0.88, 0.88)

@onready var arc_mesh_instance: MeshInstance3D = $ArcMesh
@onready var landing_marker: MeshInstance3D = $LandingMarker

var _active: bool = false
var _alpha: float = 0.0
var _float_time: float = 0.0

var _last_start: Vector3 = Vector3.INF
var _last_end: Vector3 = Vector3.INF
var _last_height: float = -9999.0
var _last_will_score: bool = false


func _ready() -> void:
	visible = false
	scale = hidden_scale
	_setup_landing_marker()
	_set_alpha(0.0)


func _process(delta: float) -> void:
	if _active:
		if not visible:
			visible = true

		_float_time += delta * float_speed
		scale = scale.lerp(shown_scale, clampf(fade_in_speed * delta, 0.0, 1.0))
		_alpha = lerpf(_alpha, 1.0, clampf(fade_in_speed * delta, 0.0, 1.0))
		_set_alpha(_alpha)

		var y_bob := sin(_float_time) * float_amplitude
		arc_mesh_instance.position.y = y_bob
		landing_marker.position.y = y_bob
	else:
		scale = scale.lerp(hidden_scale, clampf(fade_out_speed * delta, 0.0, 1.0))
		_alpha = lerpf(_alpha, 0.0, clampf(fade_out_speed * delta, 0.0, 1.0))
		_set_alpha(_alpha)

		if _alpha <= 0.02:
			visible = false
			arc_mesh_instance.mesh = null


## Shows the hop path. If will_score is true, the landing marker becomes gold.
func show_trajectory(start_pos: Vector3, end_pos: Vector3, arc_height: float, will_score: bool = false) -> void:
	_active = true
	visible = true

	if _needs_rebuild(start_pos, end_pos, arc_height, will_score):
		_build_arc_mesh(start_pos, end_pos, arc_height)
		_update_landing_marker_material(will_score)
		_last_start = start_pos
		_last_end = end_pos
		_last_height = arc_height
		_last_will_score = will_score

	landing_marker.global_position = end_pos + Vector3(0.0, y_offset, 0.0)


func hide_preview() -> void:
	_active = false


func _needs_rebuild(start_pos: Vector3, end_pos: Vector3, arc_height: float, will_score: bool) -> bool:
	if _last_start == Vector3.INF:
		return true
	if _last_start.distance_to(start_pos) > 0.01:
		return true
	if _last_end.distance_to(end_pos) > 0.01:
		return true
	if abs(_last_height - arc_height) > 0.01:
		return true
	if _last_will_score != will_score:
		return true
	return false


func _setup_landing_marker() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = landing_radius
	mesh.bottom_radius = landing_radius
	mesh.height = landing_height
	mesh.radial_segments = 24
	landing_marker.mesh = mesh
	_update_landing_marker_material(false)


func _update_landing_marker_material(will_score: bool) -> void:
	var color := scoring_color if will_score else landing_color

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	landing_marker.material_override = mat


func _build_arc_mesh(start_pos: Vector3, end_pos: Vector3, arc_height: float) -> void:
	var points: Array[Vector3] = []

	for i in range(segment_count + 1):
		var t := i / float(segment_count)
		var pos := start_pos.lerp(end_pos, t)
		pos.y += sin(t * PI) * arc_height
		pos.y += y_offset
		points.append(pos)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var pattern_len: int = dash_draw_segments + dash_gap_segments
	if pattern_len <= 0:
		pattern_len = 1

	for i in range(points.size() - 1):
		var is_last_segment := i == points.size() - 2
		var draw_this := true

		if not (always_draw_last_dash and is_last_segment):
			var pattern_index := i % pattern_len
			draw_this = pattern_index < dash_draw_segments

		if not draw_this:
			continue

		var t0 := i / float(segment_count)
		var t1 := (i + 1) / float(segment_count)

		var a := points[i]
		var b := points[i + 1]

		var forward := (b - a).normalized()
		if forward.length() <= 0.0001:
			continue

		var mid := (a + b) * 0.5
		var to_camera := (camera.global_position - mid).normalized()
		var side := forward.cross(to_camera).normalized()
		if side.length() <= 0.0001:
			side = Vector3.RIGHT

		var width0 := _get_width_at_t(t0)
		var width1 := _get_width_at_t(t1)

		var side0 := side * (width0 * 0.5)
		var side1 := side * (width1 * 0.5)

		var alpha0 := _get_alpha_at_t(t0)
		var alpha1 := _get_alpha_at_t(t1)

		var c0 := Color(arc_color.r, arc_color.g, arc_color.b, alpha0)
		var c1 := Color(arc_color.r, arc_color.g, arc_color.b, alpha1)

		var v0 := a - side0
		var v1 := a + side0
		var v2 := b - side1
		var v3 := b + side1

		# front
		st.set_color(c0)
		st.add_vertex(v0)
		st.set_color(c0)
		st.add_vertex(v1)
		st.set_color(c1)
		st.add_vertex(v2)

		st.set_color(c1)
		st.add_vertex(v2)
		st.set_color(c0)
		st.add_vertex(v1)
		st.set_color(c1)
		st.add_vertex(v3)

		# back
		st.set_color(c1)
		st.add_vertex(v2)
		st.set_color(c0)
		st.add_vertex(v1)
		st.set_color(c0)
		st.add_vertex(v0)

		st.set_color(c1)
		st.add_vertex(v3)
		st.set_color(c0)
		st.add_vertex(v1)
		st.set_color(c1)
		st.add_vertex(v2)

	var mesh := st.commit()
	arc_mesh_instance.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	arc_mesh_instance.material_override = mat


func _get_width_at_t(t: float) -> float:
	var center_weight := sin(t * PI)
	return arc_width * (1.0 + center_weight * center_width_boost)


func _get_alpha_at_t(t: float) -> float:
	var center_weight := sin(t * PI)
	return lerpf(end_alpha, center_alpha, center_weight)


func _set_alpha(value: float) -> void:
	if arc_mesh_instance.material_override is StandardMaterial3D:
		var mat := arc_mesh_instance.material_override as StandardMaterial3D
		mat.albedo_color = Color(1.0, 1.0, 1.0, value)
		if mat.emission_enabled:
			mat.emission = Color(value, value, value, value)

	if landing_marker.material_override is StandardMaterial3D:
		var mat2 := landing_marker.material_override as StandardMaterial3D
		var base_color := scoring_color if _last_will_score else landing_color
		var c2 := base_color
		c2.a = value
		mat2.albedo_color = c2
		if mat2.emission_enabled:
			mat2.emission = Color(base_color.r, base_color.g, base_color.b, value)
