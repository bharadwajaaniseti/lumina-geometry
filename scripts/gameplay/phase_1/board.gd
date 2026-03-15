extends Node2D
class_name Board

signal play_rect_changed(new_rect: Rect2)

@export var shape_scene: PackedScene
@export var base_capacity: int = 20
@export var max_capacity: int = 100

@export var shape_burst_scene: PackedScene
@export var merge_vfx_scene: PackedScene
@export var sfx_merge_path: NodePath

@export var spawn_pop_enabled: bool = true
@export var spawn_ring_enabled: bool = true

# Phase 1 loop: when the final shape type completes, trigger a calm system pulse,
# increase the run multiplier, clear the board, and restart spawning from the base.
@export var loop_multiplier_increment: float = 0.02
@export var pulse_radius: float = 420.0
@export var pulse_time: float = 0.45

@onready var shapes_container: Node2D = $ShapesContainer
@onready var gravity_anchor: Node2D = $GravityAnchor

var _avoid_rects: Array[Rect2] = []

var snap_distance_bonus: float = 0.0
var economy: Node = null
var spawner: Node = null

var _dragging: Shape = null
var _sfx_merge: AudioStreamPlayer = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _vp_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(1152, 648))
var _play_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(1152, 648))

func _ready() -> void:
	_rng.randomize()

	if sfx_merge_path != NodePath():
		_sfx_merge = get_node_or_null(sfx_merge_path) as AudioStreamPlayer

	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

func _on_viewport_resized() -> void:
	_vp_rect = get_viewport().get_visible_rect()
	_recompute_play_rect()
	play_rect_changed.emit(_play_rect)

func init_systems(p_economy: Node, p_spawner: Node) -> void:
	economy = p_economy
	spawner = p_spawner

func clear_all_shapes() -> void:
	for child: Node in shapes_container.get_children():
		if child is Shape:
			child.queue_free()

func set_avoid_rects(rects: Array[Rect2]) -> void:
	_avoid_rects = rects
	_recompute_play_rect()
	play_rect_changed.emit(_play_rect)

func _is_over_blocking_ui() -> bool:
	var c: Control = get_viewport().gui_get_hovered_control() as Control
	while c != null:
		if c.visible and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true
		c = c.get_parent() as Control
	return false

func is_point_in_ui(p_screen: Vector2) -> bool:
	for r: Rect2 in _avoid_rects:
		if r.has_point(p_screen):
			return true
	return false

func get_view_rect() -> Rect2: return _vp_rect
func get_play_rect() -> Rect2: return _play_rect
func get_play_center() -> Vector2: return _play_rect.position + (_play_rect.size * 0.5)
func get_play_size() -> Vector2: return _play_rect.size

func _recompute_play_rect() -> void:
	var safe: Rect2 = _vp_rect

	for r: Rect2 in _avoid_rects:
		if r.size.x > safe.size.x * 0.6 and r.position.y <= safe.position.y + 60.0:
			var cut: float = (r.position.y + r.size.y) - safe.position.y
			if cut > 0.0:
				safe.position.y += cut
				safe.size.y -= cut

		if r.size.x > safe.size.x * 0.6 and r.position.y >= (_vp_rect.size.y - r.size.y - 60.0):
			var cutb: float = (safe.position.y + safe.size.y) - r.position.y
			if cutb > 0.0:
				safe.size.y -= cutb

	for r: Rect2 in _avoid_rects:
		if r.position.x >= _vp_rect.size.x * 0.5:
			var new_w: float = r.position.x - safe.position.x
			safe.size.x = min(safe.size.x, new_w)

	var pad: float = 12.0
	safe.position += Vector2(pad, pad)
	safe.size -= Vector2(pad * 2.0, pad * 2.0)

	safe.size.x = max(64.0, safe.size.x)
	safe.size.y = max(64.0, safe.size.y)

	_play_rect = safe

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mbe: InputEventMouseButton = event
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				_try_begin_drag(get_viewport().get_mouse_position())
			else:
				_end_drag()

func _process(delta: float) -> void:
	if _dragging != null and is_instance_valid(_dragging):
		_dragging.drag_follow(get_viewport().get_mouse_position(), delta)

func _try_begin_drag(pos: Vector2) -> void:
	if _is_over_blocking_ui():
		return
	var hit: Shape = _pick_shape_at_point(pos)
	if hit == null:
		return
	_dragging = hit
	_dragging.begin_drag()

func _end_drag() -> void:
	if _dragging == null:
		return
	if is_instance_valid(_dragging):
		_dragging.end_drag()
	_dragging = null

func _pick_shape_at_point(pos: Vector2) -> Shape:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var results: Array[Dictionary] = space.intersect_point(query, 16)
	for r: Dictionary in results:
		var collider_obj: Object = (r.get("collider") as Object)
		if collider_obj is Shape:
			return collider_obj as Shape
	return null

func active_shapes_count() -> int:
	return shapes_container.get_child_count()

func capacity() -> int:
	var bonus: int = 0
	if spawner != null and spawner.has_method("get_capacity_bonus"):
		bonus = int(spawner.call("get_capacity_bonus"))
	return clamp(base_capacity + bonus, base_capacity, max_capacity)

func register_shape(s: Shape) -> void:
	shapes_container.add_child(s)

	s.gravity_center = gravity_anchor.global_position
	s.merge_requested.connect(_on_shape_merge_requested)
	s.snap_distance = s.snap_distance + snap_distance_bonus

	if spawn_pop_enabled:
		_spawn_pop(s)
	if spawn_ring_enabled:
		var c: Color = s.get_vfx_color()
		_spawn_ring(s.global_position, c)

# ✅ MERGE RULES:
# Same shape_type_index + same color_rank -> rank+1
# If at last rank -> next shape type rank 0 (unlock milestone)
func _on_shape_merge_requested(a: Shape, b: Shape) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	if not a.matches(b):
		return

	var pos: Vector2 = (a.global_position + b.global_position) * 0.5

	var cps: int = 10
	if a.db != null:
		cps = max(int(a.db.colors_per_shape), 1)

	var next_type: int = a.shape_type_index
	var next_rank: int = a.color_rank
	var unlocked_new_shape: bool = false

	if a.color_rank < cps - 1:
		next_rank = a.color_rank + 1
	else:
		next_rank = 0
		next_type = a.shape_type_index + 1
		unlocked_new_shape = true

	# Capture everything needed BEFORE queue_free
	var db_ref: ShapeDB = a.db
	var inventory_unlock_id: String = ""

	if unlocked_new_shape and db_ref != null and db_ref.shape_types != null:
		if next_type >= 0 and next_type < db_ref.shape_types.size():
			var next_def = db_ref.shape_types[next_type]
			if next_def != null:
				var display_name_value = next_def.get("display_name")
				if display_name_value != null and str(display_name_value).strip_edges() != "":
					inventory_unlock_id = str(display_name_value)
				else:
					var raw_id = next_def.get("id")
					if raw_id != null and str(raw_id).strip_edges() != "":
						inventory_unlock_id = str(raw_id)

	var reached_max_cycle: bool = false
	if unlocked_new_shape and db_ref != null:
		if db_ref.shape_types != null and next_type >= db_ref.shape_types.size():
			reached_max_cycle = true

	if economy != null and economy.has_method("on_merge"):
		economy.call("on_merge", a.shape_type_index, a.color_rank, a.tier)

	if _dragging == a or _dragging == b:
		_dragging = null

	a.queue_free()
	b.queue_free()

	if reached_max_cycle:
		_trigger_system_pulse(pos)
		return

	if unlocked_new_shape:
		if spawner != null and spawner.has_method("unlock_shape_type"):
			spawner.call("unlock_shape_type", next_type)

		if inventory_unlock_id.strip_edges() != "":
			Game_State.unlock_inventory_shape(inventory_unlock_id)

	var new_shape: Shape = _spawn_shape_ids(next_type, next_rank, pos)
	_play_merge_feedback(pos, new_shape)

func _spawn_shape_ids(type_index: int, rank: int, pos: Vector2) -> Shape:
	var s: Shape = shape_scene.instantiate() as Shape
	s.set_ids(type_index, rank)
	s.global_position = pos

	if spawner != null and spawner.has_method("pick_motion_type"):
		var mt_var: Variant = spawner.call("pick_motion_type")
		s.motion_type = (int(mt_var) as Shape.MotionType)

	register_shape(s)
	return s

func _spawn_pop(s: Shape) -> void:
	var vis: Node2D = s.get_node_or_null("Visual") as Node2D
	if vis == null:
		return
	var base: Vector2 = vis.scale
	vis.scale = base * 0.10

	if vis is CanvasItem:
		var ci := vis as CanvasItem
		var m := ci.modulate
		m.a = 0.0
		ci.modulate = m

	var tw_scale := create_tween()
	tw_scale.tween_property(vis, "scale", base * 1.12, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_scale.tween_property(vis, "scale", base, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if vis is CanvasItem:
		var tw_alpha := create_tween()
		tw_alpha.tween_property(vis, "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _spawn_ring(pos: Vector2, c: Color) -> void:
	if merge_vfx_scene == null:
		return
	var vfx_node: Node = merge_vfx_scene.instantiate()
	if vfx_node is Node2D:
		var vfx := vfx_node as Node2D
		add_child(vfx)
		vfx.global_position = pos
		if vfx.has_method("setup"):
			vfx.call("setup", c, 8.0, 55.0, 0.16)

func _play_merge_feedback(pos: Vector2, s: Shape) -> void:
	var c: Color = Color.WHITE
	var tex: Texture2D = null

	if s != null and is_instance_valid(s):
		c = s.get_vfx_color()
		tex = s.get_texture()

	if merge_vfx_scene != null:
		var vfx_node: Node = merge_vfx_scene.instantiate()
		if vfx_node is Node2D:
			var vfx := vfx_node as Node2D
			add_child(vfx)
			vfx.global_position = pos
			if vfx.has_method("setup"):
				vfx.call("setup", c, 14.0, 90.0, 0.22)

	if shape_burst_scene != null and tex != null:
		var burst_node: Node = shape_burst_scene.instantiate()
		if burst_node is Node2D:
			var burst := burst_node as Node2D
			add_child(burst)
			burst.global_position = pos
			if burst.has_method("setup"):
				burst.call("setup", tex, c)

	if _sfx_merge != null:
		_sfx_merge.pitch_scale = _rng.randf_range(0.96, 1.08)
		_sfx_merge.volume_db = -10.0
		_sfx_merge.play()

func _trigger_system_pulse(center_pos: Vector2) -> void:
	_dragging = null

	# Pause spawning during pulse
	if spawner != null and spawner.has_method("set_spawning_enabled"):
		spawner.call("set_spawning_enabled", false)

	# Increase multiplier first (so HUD can show it immediately)
	if economy != null and economy.has_method("add_run_multiplier"):
		economy.call("add_run_multiplier", loop_multiplier_increment)

	# Tell HUD what happened
	var mult_txt := ""
	if economy != null and economy.has_method("get_run_multiplier"):
		mult_txt = " x%0.2f" % float(economy.call("get_run_multiplier"))
	get_tree().call_group("hud", "push_system_log", "Threshold reached. Multiplier increased." + mult_txt)

	# ✅ Visible pulse color (soft cyan)
	var pulse_color := Color(0.55, 0.90, 1.00, 1.0)

	# Big ring pulse
	if merge_vfx_scene != null:
		var vfx_node: Node = merge_vfx_scene.instantiate()
		if vfx_node is Node2D:
			var vfx := vfx_node as Node2D
			add_child(vfx)
			vfx.global_position = center_pos

			# Make it thick + visible
			var ring := vfx.get_node_or_null("Ring") as Line2D
			if ring != null:
				ring.width = 12.0

			if vfx.has_method("setup"):
				vfx.call("setup", pulse_color, 16.0, pulse_radius, pulse_time)

	# Fade shapes as pulse reaches them (same as before)
	var shapes: Array[Shape] = get_shapes()
	for s in shapes:
		_fade_shape_by_pulse(s, center_pos, pulse_radius, pulse_time)

	await get_tree().create_timer(pulse_time + 0.06).timeout

	# Clear all shapes
	for s in shapes:
		if is_instance_valid(s):
			s.queue_free()
	clear_all_shapes()

	# Restart spawning
	if spawner != null and spawner.has_method("reset_progression"):
		spawner.call("reset_progression")

	if spawner != null and spawner.has_method("set_spawning_enabled"):
		spawner.call("set_spawning_enabled", true)

func _fade_shape_by_pulse(s: Shape, center_pos: Vector2, radius: float, life: float) -> void:
	if s == null or not is_instance_valid(s):
		return

	# Prefer fading the Sprite (Visual), fallback to the body itself
	var target: CanvasItem = s.visual if s.visual != null else s as CanvasItem
	if target == null:
		return

	var d: float = center_pos.distance_to(s.global_position)
	var t: float = clamp(d / max(radius, 1.0), 0.0, 1.0)

	# Wave travel delay: 0 → life
	# Slight bias so most shapes fade during the pulse (not after)
	var delay: float = t * (life * 0.92)

	# Fade duration should be short and clean (no drama)
	var fade_time: float = 0.12
	s.freeze = true
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_interval(delay)
	tw.tween_property(target, "modulate:a", 0.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

# Auto merge uses the SAME matching rules now
func get_shapes() -> Array[Shape]:
	var arr: Array[Shape] = []
	for child: Node in shapes_container.get_children():
		if child is Shape:
			arr.append(child as Shape)
	return arr

func try_auto_merge(max_distance: float) -> bool:
	var shapes: Array[Shape] = get_shapes()
	if shapes.size() < 2:
		return false

	var best_a: Shape = null
	var best_b: Shape = null
	var best_d2: float = INF
	var max_d2: float = max_distance * max_distance

	for i in range(shapes.size()):
		var a: Shape = shapes[i]
		if not is_instance_valid(a):
			continue
		for j in range(i + 1, shapes.size()):
			var b: Shape = shapes[j]
			if not is_instance_valid(b):
				continue
			if not a.matches(b):
				continue
			var d2 := a.global_position.distance_squared_to(b.global_position)
			if d2 < best_d2:
				best_d2 = d2
				best_a = a
				best_b = b

	if best_a == null or best_b == null:
		return false
	if best_d2 > max_d2:
		return false

	_on_shape_merge_requested(best_a, best_b)
	return true
