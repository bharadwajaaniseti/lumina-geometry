extends Node
class_name Spawner

# ✅ Assign in Inspector (recommended)
@export var shape_db: ShapeDB

@export var spawn_interval: float = 1.0
@export var spawn_jitter: float = 0.25

@export var slowdown_at_capacity: bool = true
@export var capacity_slowdown_factor: float = 2.0

# ----- Spawn behaviour -----
@export var offscreen_spawn_chance: float = 0.25
@export var offscreen_margin: float = 80.0
@export var enter_impulse_min: float = 140.0
@export var enter_impulse_max: float = 260.0

# Chance to spawn rank 1 instead of rank 0 (kept name so your Inspector doesn't break)
@export var direct_tier2_chance: float = 0.0

# Motion weights
@export var weight_drifter: float = 0.35
@export var weight_seeker: float = 0.25
@export var weight_orbiter: float = 0.25
@export var weight_chaos: float = 0.15

# -------------------------
# ✅ RULE 1 SETTINGS
# -------------------------
@export var spawn_only_active_type: bool = true
@export var active_spawn_shape_type: int = 0  # 0 = Circle (base)

# (Optional) Later, if you want: allow spawning unlocked types too
@export var allow_unlocked_type_spawns: bool = false

# Unlock tracking (still useful later)
@export var start_unlocked_shape_types: int = 1
var _unlocked_max_shape_type: int = 0

var capacity_bonus: int = 0

var board: Board = null
var shape_scene: PackedScene = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timer: float = 0.0
var _enabled: bool = true
var _spawn_rate_mult: float = 1.0

func _ready() -> void:
	_rng.randomize()
	normalize_weights()

func init(p_board: Board, p_shape_scene: PackedScene) -> void:
	board = p_board
	shape_scene = p_shape_scene
	_unlocked_max_shape_type = max(start_unlocked_shape_types - 1, 0)

	# Fallback: if shape_db not set, try pull it from Shape scene instance
	if shape_db == null and shape_scene != null:
		var tmp: Node = shape_scene.instantiate()
		if tmp is Shape:
			shape_db = (tmp as Shape).db
		if is_instance_valid(tmp):
			tmp.queue_free()

	_timer = _next_interval()

# Called when the player completes the max shape cycle (Phase 1 loop).
# Resets spawning back to the base shape.
func reset_progression() -> void:
	active_spawn_shape_type = 0
	_unlocked_max_shape_type = max(start_unlocked_shape_types - 1, 0)
	_timer = _next_interval()

func unlock_shape_type(shape_type_index: int) -> void:
	_unlocked_max_shape_type = max(_unlocked_max_shape_type, shape_type_index)
	if spawn_only_active_type:
		active_spawn_shape_type = _unlocked_max_shape_type

func set_active_spawn_shape_type(shape_type_index: int) -> void:
	active_spawn_shape_type = max(shape_type_index, 0)

func set_spawning_enabled(v: bool) -> void:
	_enabled = v
	if _enabled:
		_timer = _next_interval()

func set_spawn_rate_multiplier(mult: float) -> void:
	_spawn_rate_mult = max(0.05, mult)
	if _enabled:
		_timer = min(_timer, _next_interval())

func _process(delta: float) -> void:
	if not _enabled:
		return
	if board == null or shape_scene == null:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	if board.active_shapes_count() >= board.capacity():
		_timer = _next_interval() * (capacity_slowdown_factor if slowdown_at_capacity else 1.0)
		return

	_spawn_auto()
	_timer = _next_interval()

func _next_interval() -> float:
	var effective_interval: float = spawn_interval / _spawn_rate_mult
	var jittered: float = effective_interval + _rng.randf_range(-spawn_jitter, spawn_jitter)
	return max(0.20, jittered)

func _spawn_auto() -> void:
	var s: Shape = shape_scene.instantiate() as Shape

	# ✅ Force DB into every spawned shape (prevents tint/logic issues)
	if shape_db != null:
		s.db = shape_db

	# Determine colors-per-shape
	var cps: int = 10
	if shape_db != null:
		cps = max(int(shape_db.colors_per_shape), 1)

	# -------------------------
	# ✅ RULE 1: pick shape type
	# -------------------------
	var type_index: int = 0

	if spawn_only_active_type:
		type_index = clampi(active_spawn_shape_type, 0, 999999)
	elif allow_unlocked_type_spawns and shape_db != null and not shape_db.shape_types.is_empty():
		var max_i: int = min(_unlocked_max_shape_type, shape_db.shape_types.size() - 1)
		max_i = max(max_i, 0)
		type_index = _rng.randi_range(0, max_i)
	else:
		# fallback
		type_index = clampi(active_spawn_shape_type, 0, 999999)

	# Spawn rank 0 mostly (optionally rank 1)
	var rank: int = 0
	if cps > 1 and direct_tier2_chance > 0.0 and _rng.randf() < direct_tier2_chance:
		rank = 1

	# Your Shape script supports set_ids()
	if s.has_method("set_ids"):
		s.call("set_ids", type_index, rank)
	else:
		# Legacy fallback
		s.set_tier(1)

	var play_rect: Rect2 = board.get_play_rect()
	var center: Vector2 = play_rect.position + play_rect.size * 0.5

	var spawn_pos: Vector2
	var spawned_offscreen: bool = false

	if _rng.randf() < offscreen_spawn_chance:
		spawn_pos = _random_offscreen_edge(play_rect, offscreen_margin)
		spawned_offscreen = true
	else:
		spawn_pos = Vector2(
			_rng.randf_range(play_rect.position.x, play_rect.position.x + play_rect.size.x),
			_rng.randf_range(play_rect.position.y, play_rect.position.y + play_rect.size.y)
		)

	s.global_position = spawn_pos
	s.motion_type = pick_motion_type()

	if spawned_offscreen:
		var rb: RigidBody2D = s as RigidBody2D
		var dir: Vector2 = (center - spawn_pos).normalized()
		rb.linear_velocity += dir * _rng.randf_range(enter_impulse_min, enter_impulse_max)

	board.register_shape(s)

func _random_offscreen_edge(play_rect: Rect2, margin: float) -> Vector2:
	var side: int = _rng.randi_range(0, 3)

	var left: float = play_rect.position.x
	var right: float = play_rect.position.x + play_rect.size.x
	var top: float = play_rect.position.y
	var bottom: float = play_rect.position.y + play_rect.size.y

	match side:
		0: return Vector2(left - margin, _rng.randf_range(top, bottom))
		1: return Vector2(right + margin, _rng.randf_range(top, bottom))
		2: return Vector2(_rng.randf_range(left, right), top - margin)
		3: return Vector2(_rng.randf_range(left, right), bottom + margin)
		_: return play_rect.position + play_rect.size * 0.5

func pick_motion_type() -> Shape.MotionType:
	var r: float = _rng.randf()
	var a: float = weight_drifter
	var b: float = a + weight_seeker
	var c: float = b + weight_orbiter

	if r < a:
		return Shape.MotionType.DRIFTER
	elif r < b:
		return Shape.MotionType.SEEKER
	elif r < c:
		return Shape.MotionType.ORBITER
	else:
		return Shape.MotionType.CHAOS

func normalize_weights() -> void:
	var total: float = weight_drifter + weight_seeker + weight_orbiter + weight_chaos
	if total <= 0.0001:
		weight_drifter = 0.35
		weight_seeker = 0.25
		weight_orbiter = 0.25
		weight_chaos = 0.15
		return
	weight_drifter /= total
	weight_seeker /= total
	weight_orbiter /= total
	weight_chaos /= total

func get_capacity_bonus() -> int:
	return capacity_bonus
