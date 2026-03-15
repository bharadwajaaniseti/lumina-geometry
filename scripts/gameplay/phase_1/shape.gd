extends RigidBody2D
class_name Shape

signal merge_requested(a: Shape, b: Shape)

enum State { IDLE, DRAGGING, LOCKED, MERGING }
enum MotionType { DRIFTER, SEEKER, ORBITER, CHAOS }

# -------------------------
# DB
# -------------------------
@export var db: ShapeDB

var _sync_lock: bool = false

# tiers are 1-based (tier 1 => DB index 0)
@export var tier: int = 1:
	set(value):
		tier = max(value, 1)
		if not _sync_lock:
			_sync_ids_from_tier()
		if is_node_ready():
			_sync_visual()
	get:
		return tier

# -------------------------
# NEW: ShapeType + ColorRank system
# -------------------------
@export var shape_type_index: int = 0:
	set(value):
		shape_type_index = max(value, 0)
		if not _sync_lock:
			_sync_tier_from_ids()
		if is_node_ready():
			_sync_visual()
	get:
		return shape_type_index

@export var color_rank: int = 0:
	set(value):
		color_rank = max(value, 0)
		if not _sync_lock:
			_sync_tier_from_ids()
		if is_node_ready():
			_sync_visual()
	get:
		return color_rank

# Visual sizing
@export var sprite_scale: float = 0.2
@export var collision_fill: float = 0.88
@export var snap_radius_multiplier: float = 1.35

# Snap-to-merge
@export var snap_distance: float = 60.0
@export var follow_smooth: float = 20.0

# Motion settings
@export var motion_type: MotionType = MotionType.DRIFTER
@export var max_speed: float = 260.0
@export var drift_strength: float = 22.0
@export var center_pull_strength: float = 20.0
@export var orbit_strength: float = 26.0
@export var chaos_strength: float = 70.0
@export var chaos_impulse_interval: float = 0.35
@export var velocity_steer: float = 10.0
@export var seeker_wobble_amp: float = 0.35
@export var seeker_wobble_freq: float = 1.4
@export var orbiter_wobble_amp: float = 0.18
@export var orbiter_wobble_freq: float = 0.9

var _t: float = 0.0
var _seed: float = 0.0

# Drag smoothness
@export var drag_follow_strength: float = 28.0
@export var drag_max_release_speed: float = 900.0
@export var drag_release_boost: float = 1.0

var _drag_prev_pos: Vector2 = Vector2.ZERO
var _drag_velocity: Vector2 = Vector2.ZERO

# Smooth drift/noise
@export var noise_turn_speed: float = 6.0

# Offscreen behaviour
@export var allow_offscreen_margin: float = 120.0
@export var return_margin: float = 220.0 # kept for compatibility (not used directly)
@export var return_strength: float = 28.0
@export var delete_margin: float = 520.0
@export var delete_when_far: bool = true

# -------------------------
# RULE 4: Important shape stability
# -------------------------
@export var important_rank_buffer: int = 2          # top N ranks are important
@export var important_speed_mult: float = 0.65      # slower cap for important shapes
@export var important_linear_damp_bonus: float = 2.0
@export var important_return_mult: float = 2.5
@export var important_never_delete: bool = true

var glow: Sprite2D = null
var _glow_mat: CanvasItemMaterial = null
# -------------------------
# Important Glow (Rule 4 extra)
# -------------------------
@export var important_glow_enabled: bool = true
@export var important_glow_alpha: float = 0.22      # 0.12–0.35 good
@export var important_glow_scale: float = 1.22      # 1.12–1.35 good
@export var important_glow_boost: float = 1.0       # multiplies glow color brightness

# Target locking behavior
@export var lock_target_while_dragging: bool = true

@onready var snap_area: Area2D = get_node_or_null("SnapArea") as Area2D
@onready var visual: Sprite2D = get_node_or_null("Visual") as Sprite2D
@onready var main_col: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

# Tint controls
@export var tint_sprite_by_rank: bool = true
@export var tint_strength: float = 1.0

var state: State = State.IDLE
var reserved: bool = false

var snap_target: Shape = null
var _locked_candidate: Shape = null

var gravity_center: Vector2 = Vector2.ZERO

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _noise_dir: Vector2 = Vector2.RIGHT
var _noise_target: Vector2 = Vector2.RIGHT
var _noise_timer: float = 0.0
var _chaos_timer: float = 0.0

func _ready() -> void:
	_rng.randomize()
	_seed = _rng.randf_range(0.0, 1000.0)

	gravity_scale = 0.0
	# base damping (Rule 4 will override per-frame)
	linear_damp = 3.5
	angular_damp = 8.0

	_sync_visual()

	_noise_target = Vector2.from_angle(_rng.randf_range(0.0, TAU))
	_noise_dir = _noise_target
	_noise_timer = _rng.randf_range(0.2, 0.7)
	_chaos_timer = _rng.randf_range(0.0, chaos_impulse_interval)

	apply_central_impulse(
		Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(10.0, 30.0)
	)

func set_tier(new_tier: int) -> void:
	tier = new_tier

func set_ids(type_index: int, rank: int) -> void:
	_sync_lock = true
	shape_type_index = max(type_index, 0)
	color_rank = max(rank, 0)
	_sync_lock = false

	_sync_tier_from_ids()

	if is_node_ready():
		_sync_visual()

# -------------------------
# Visual + Collision Sync
# -------------------------
func _tier_index() -> int:
	return max(tier - 1, 0)

func _sync_visual() -> void:
	if visual == null:
		return

	visual.centered = true

	# Texture: prefer new system, fallback to legacy tier textures if needed
	var tex: Texture2D = null
	if db != null and db.has_method("get_texture") and not db.shape_types.is_empty():
		tex = db.get_texture(shape_type_index, color_rank)

	if tex == null and db != null:
		var idx: int = _tier_index()
		if idx >= 0 and idx < db.tier_textures.size():
			tex = db.tier_textures[idx]

	visual.texture = tex

	# --- RULE 2: Progress-readable sizing ---
	var cps: int = 10
	if db != null:
		cps = max(int(db.colors_per_shape), 1)

	var rank_scale: float = 1.0 + (float(color_rank) * 0.02)       # 2% per color
	var type_scale: float = 1.0 + (float(shape_type_index) * 0.08) # 8% per shape type

	rank_scale = min(rank_scale, 1.0 + (float(cps - 1) * 0.02))
	type_scale = min(type_scale, 1.0 + 8.0 * 0.08)

	var final_scale: float = sprite_scale * rank_scale * type_scale
	visual.scale = Vector2(final_scale, final_scale)

	# Tint from palette
	if tint_sprite_by_rank and db != null and db.color_rank_palette.size() > 0:
		var pi: int = clampi(color_rank, 0, db.color_rank_palette.size() - 1)
		var target: Color = db.color_rank_palette[pi]

		var a: float = clampf(tint_strength, 0.0, 1.0)
		var blended: Color = Color.WHITE.lerp(target, a)
		blended.a = 1.0

		visual.self_modulate = blended
		visual.modulate = blended
	else:
		visual.self_modulate = Color.WHITE
		visual.modulate = Color.WHITE
		# --- Important Glow ---
	_ensure_glow_sprite()

	if glow != null:
		var important: bool = _is_important() and important_glow_enabled and (visual.texture != null)

		glow.visible = important
		if important:
			# Match texture & position
			glow.texture = visual.texture
			glow.global_position = visual.global_position

			# Scale slightly bigger than the main sprite
			glow.scale = visual.scale * important_glow_scale

			# Glow color = same as rank tint (or palette), but with low alpha
			var glow_color: Color = visual.self_modulate

			# optional brightness boost
			glow_color.r = clampf(glow_color.r * important_glow_boost, 0.0, 1.0)
			glow_color.g = clampf(glow_color.g * important_glow_boost, 0.0, 1.0)
			glow_color.b = clampf(glow_color.b * important_glow_boost, 0.0, 1.0)
			glow_color.a = clampf(important_glow_alpha, 0.0, 1.0)

			glow.self_modulate = glow_color
	_fit_collisions_to_sprite()

func _fit_collisions_to_sprite() -> void:
	if visual == null or visual.texture == null:
		return

	var tex_size: Vector2 = visual.texture.get_size() * visual.scale
	var sprite_radius: float = min(tex_size.x, tex_size.y) * 0.5

	if main_col != null and main_col.shape is CircleShape2D:
		var c: CircleShape2D = main_col.shape as CircleShape2D
		c.radius = sprite_radius * collision_fill

	if snap_area != null:
		var snap_col: CollisionShape2D = snap_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if snap_col != null and snap_col.shape is CircleShape2D and main_col != null and main_col.shape is CircleShape2D:
			var mc: CircleShape2D = main_col.shape as CircleShape2D
			var sc: CircleShape2D = snap_col.shape as CircleShape2D
			sc.radius = mc.radius * snap_radius_multiplier

# -------------------------
# Drag API (called by Board)
# -------------------------
func begin_drag() -> void:
	if state != State.IDLE or reserved:
		return

	state = State.DRAGGING
	freeze = true

	_drag_prev_pos = global_position
	_drag_velocity = Vector2.ZERO

	snap_target = null
	_unlock_candidate()

func end_drag() -> void:
	if state != State.DRAGGING:
		return

	state = State.IDLE
	freeze = false
	sleeping = false

	var v: Vector2 = _drag_velocity * drag_release_boost
	if v.length() > drag_max_release_speed:
		v = v.normalized() * drag_max_release_speed
	linear_velocity = v

	snap_target = null
	_unlock_candidate()

func drag_follow(mouse_pos: Vector2, delta: float) -> void:
	if state != State.DRAGGING:
		return

	var t: float = 1.0 - exp(-drag_follow_strength * delta)
	var new_pos: Vector2 = global_position.lerp(mouse_pos, t)

	_drag_velocity = (new_pos - _drag_prev_pos) / max(delta, 0.0001)
	_drag_prev_pos = new_pos

	global_position = new_pos

	_update_snap_target()
	_try_snap_and_merge()

func _physics_process(delta: float) -> void:
	if state == State.DRAGGING:
		return
	if state == State.LOCKED or state == State.MERGING:
		return

	_apply_importance_stability() # ✅ RULE 4
	_update_noise(delta)
	_apply_motion(delta)
	_apply_offscreen_rules()
	_soft_cap_speed()

# -------------------------
# RULE 4 helpers
# -------------------------
func _is_important() -> bool:
	var cps: int = 10
	if db != null:
		cps = max(int(db.colors_per_shape), 1)

	var buffer: int = max(important_rank_buffer, 1)
	var is_high_rank: bool = color_rank >= cps - buffer
	var is_new_type: bool = shape_type_index > 0
	return is_high_rank or is_new_type

func _apply_importance_stability() -> void:
	# Calmer movement via damping for important shapes
	if _is_important():
		linear_damp = 3.5 + important_linear_damp_bonus
		angular_damp = 8.0 + (important_linear_damp_bonus * 1.2)
	else:
		linear_damp = 3.5
		angular_damp = 8.0

# -------------------------
# Merge targeting
# -------------------------
func _update_snap_target() -> void:
	if snap_area == null:
		return

	var candidates: Array = snap_area.get_overlapping_bodies()
	var best: Shape = null
	var best_d2: float = INF

	for body in candidates:
		if body == self:
			continue
		if body is Shape:
			var s: Shape = body as Shape
			if not matches(s):
				continue
			if s.reserved:
				continue
			if s.state != State.IDLE and s.state != State.LOCKED:
				continue

			var d2: float = global_position.distance_squared_to(s.global_position)
			if d2 < best_d2:
				best_d2 = d2
				best = s

	snap_target = best

	if lock_target_while_dragging:
		_lock_candidate(snap_target)

func _lock_candidate(target: Shape) -> void:
	if target == _locked_candidate:
		return

	_unlock_candidate()

	if target == null:
		return

	if target.state == State.IDLE and not target.reserved:
		_locked_candidate = target
		target.state = State.LOCKED
		target.freeze = true
		target.linear_velocity = Vector2.ZERO
		target.angular_velocity = 0.0

func _unlock_candidate() -> void:
	if _locked_candidate == null:
		return
	if is_instance_valid(_locked_candidate):
		if _locked_candidate.state == State.LOCKED and not _locked_candidate.reserved:
			_locked_candidate.state = State.IDLE
			_locked_candidate.freeze = false
	_locked_candidate = null

func _try_snap_and_merge() -> void:
	if snap_target == null:
		return

	var d: float = global_position.distance_to(snap_target.global_position)
	if d > snap_distance:
		return

	state = State.LOCKED
	reserved = true

	snap_target.reserved = true
	snap_target.state = State.LOCKED
	snap_target.freeze = true
	snap_target.linear_velocity = Vector2.ZERO
	snap_target.angular_velocity = 0.0

	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", snap_target.global_position, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func() -> void:
		_unlock_candidate()
		if not is_instance_valid(snap_target):
			_release_reservation()
			return
		state = State.MERGING
		snap_target.state = State.MERGING
		merge_requested.emit(self, snap_target)
	)

func _release_reservation() -> void:
	reserved = false
	state = State.IDLE
	snap_target = null
	freeze = false
	_unlock_candidate()

# -------------------------
# Motion
# -------------------------
func _update_noise(delta: float) -> void:
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = _rng.randf_range(0.25, 0.9)
		_noise_target = Vector2.from_angle(_rng.randf_range(0.0, TAU))

	var t: float = 1.0 - exp(-noise_turn_speed * delta)
	_noise_dir = _noise_dir.lerp(_noise_target, t).normalized()

func _apply_motion(delta: float) -> void:
	_t += delta

	var to_center: Vector2 = gravity_center - global_position
	var dist: float = max(to_center.length(), 0.001)
	var dir_to_center: Vector2 = to_center / dist
	var tangent: Vector2 = Vector2(-dir_to_center.y, dir_to_center.x)

	var desired: Vector2 = Vector2.ZERO

	match motion_type:
		MotionType.DRIFTER:
			desired = _noise_dir * (max_speed * 0.45)

		MotionType.SEEKER:
			var wob: float = sin((_t + _seed) * seeker_wobble_freq) * seeker_wobble_amp
			var wobble_vec: Vector2 = tangent * wob
			desired = (dir_to_center + wobble_vec).normalized() * (max_speed * 0.60)

		MotionType.ORBITER:
			var wob2: float = sin((_t + _seed) * orbiter_wobble_freq) * orbiter_wobble_amp
			var mix_dir: Vector2 = (tangent + dir_to_center * 0.35 + tangent * wob2).normalized()
			desired = mix_dir * (max_speed * 0.62)

		MotionType.CHAOS:
			_chaos_timer -= delta
			if _chaos_timer <= 0.0:
				_chaos_timer = chaos_impulse_interval * _rng.randf_range(0.9, 1.6)
				_noise_target = Vector2.from_angle(_rng.randf_range(0.0, TAU))

			var chaos_dir: Vector2 = (_noise_dir + _noise_target).normalized()
			desired = chaos_dir * (max_speed * 0.75)

	var tsteer: float = 1.0 - exp(-velocity_steer * delta)
	linear_velocity = linear_velocity.lerp(desired, tsteer)

# -------------------------
# Offscreen rules (Rule 4 strengthened)
# -------------------------
func _apply_offscreen_rules() -> void:
	var rect: Rect2 = get_viewport().get_visible_rect()

	var zone_allow: Rect2 = rect.grow(allow_offscreen_margin)
	var zone_delete: Rect2 = rect.grow(delete_margin)

	var p: Vector2 = global_position
	var important: bool = _is_important()

	# Important shapes never get deleted
	if delete_when_far and not zone_delete.has_point(p):
		if important_never_delete and important:
			# pull back instead (below)
			pass
		elif not important:
			queue_free()
			return

	# If inside safe zone → do nothing
	if zone_allow.has_point(p):
		return

	# Outside allow zone → pull back in
	var target: Vector2 = _closest_point_in_rect(zone_allow, p)
	var dir: Vector2 = target - p
	var dist: float = dir.length()

	if dist > 0.001:
		var strength: float = return_strength
		if important:
			strength *= important_return_mult
		apply_central_force(dir.normalized() * strength)

func _closest_point_in_rect(r: Rect2, p: Vector2) -> Vector2:
	var x: float = clampf(p.x, r.position.x, r.position.x + r.size.x)
	var y: float = clampf(p.y, r.position.y, r.position.y + r.size.y)
	return Vector2(x, y)

func _soft_cap_speed() -> void:
	var limit: float = max_speed
	if _is_important():
		limit *= important_speed_mult

	var spd: float = linear_velocity.length()
	if spd > limit:
		linear_velocity = linear_velocity.normalized() * limit

# -------------------------
# VFX helpers
# -------------------------
func get_vfx_color() -> Color:
	if db == null:
		return Color.WHITE
	if db.color_rank_palette.size() > 0:
		var pi: int = clampi(color_rank, 0, db.color_rank_palette.size() - 1)
		return db.color_rank_palette[pi]
	return Color.WHITE

func get_texture() -> Texture2D:
	var spr: Sprite2D = get_node_or_null("Visual") as Sprite2D
	return spr.texture if spr != null else null

# -------------------------
# Helpers
# -------------------------
func matches(other: Shape) -> bool:
	if other == null:
		return false
	return other.shape_type_index == shape_type_index and other.color_rank == color_rank

func _sync_tier_from_ids() -> void:
	if db == null:
		return
	if db.has_method("get_global_tier"):
		_sync_lock = true
		tier = int(db.get_global_tier(shape_type_index, color_rank))
		_sync_lock = false

func _sync_ids_from_tier() -> void:
	if db == null:
		return
	if db.has_method("decode_global_tier"):
		var d: Dictionary = db.decode_global_tier(tier)
		_sync_lock = true
		shape_type_index = int(d.get("shape_type", shape_type_index))
		color_rank = int(d.get("color_rank", color_rank))
		_sync_lock = false

func _ensure_glow_sprite() -> void:
	if visual == null:
		return
	if glow != null and is_instance_valid(glow):
		return

	glow = Sprite2D.new()
	glow.name = "Glow"
	glow.centered = true
	glow.texture_filter = visual.texture_filter
	glow.z_index = visual.z_index - 1
	glow.visible = false

	_glow_mat = CanvasItemMaterial.new()
	_glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = _glow_mat

	var parent := visual.get_parent()
	parent.add_child(glow)
	# Put glow just before Visual in draw order
	parent.move_child(glow, visual.get_index())
