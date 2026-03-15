extends CanvasLayer
class_name HUD

signal end_round_pressed

@export var round_duration_sec: float = 120.0
@export var goal_update_interval: float = 0.20

# --- Optional polish controls ---
@export var goal_pop_scale: float = 1.03
@export var goal_pop_time: float = 0.12
@export var goal_fade_time: float = 0.10

# --- Step 5: Subtle System Presence (Phase 1 safe) ---
@export var system_log_interval: float = 12.0
@export var system_log_fade_time: float = 0.25
@export var system_log_alpha: float = 0.55

@onready var round_bar: ProgressBar = $TopBar/HBox/Left/RoundBar
@onready var btn_end: Button = $TopBar/HBox/Right/EndRound

@onready var lbl_energy: Label = $TopBar/HBox/Right/StatsPanel/StatsRow/Stat_Energy/Value
@onready var cap_energy: Label = $TopBar/HBox/Right/StatsPanel/StatsRow/Stat_Energy/Caption

@onready var lbl_stored: Label = $TopBar/HBox/Right/StatsPanel/StatsRow/Stat_Stored/Value
@onready var cap_stored: Label = $TopBar/HBox/Right/StatsPanel/StatsRow/Stat_Stored/Caption

@onready var lbl_mult: Label = $TopBar/HBox/Right/StatsPanel/StatsRow/Stat_Multiplier/Value

# Milestone UI (scene-based)
@onready var goal_card: Control = $TopBar/HBox/Left/MilestoneCard
@onready var lbl_goal_title: Label = $TopBar/HBox/Left/MilestoneCard/Margin/VBox/Title
@onready var lbl_goal_main: Label  = $TopBar/HBox/Left/MilestoneCard/Margin/VBox/Goal
@onready var lbl_goal_sub: Label   = $TopBar/HBox/Left/MilestoneCard/Margin/VBox/Sub

# Optional: bottom system log label (add this node in HUD.tscn)
@onready var lbl_system_log: Label = $SystemLog

# Data sources
var _board: Board = null
var _spawner: Spawner = null
var _shape_db: ShapeDB = null

var _goal_accum: float = 0.0
var _time_left: float = 0.0
var _running: bool = false

# ✅ Timer can be disabled (infinite mode)
var _timer_enabled: bool = true

# Cache last strings to animate only on change
var _last_goal_main: String = ""
var _last_goal_sub: String = ""

# Keep original scale for pop animation
var _goal_card_base_scale: Vector2 = Vector2.ONE
var _goal_tween: Tween = null

# System log rotation state
var _system_log_accum: float = 0.0
var _system_log_index: int = 0
var _system_log_tween: Tween = null
var _system_log_lines: Array[String] = [
	"Output Stable.",
	"Optimization Ongoing.",
	"Load Balanced.",
	"Efficiency Increasing.",
	"Alignment Within Parameters.",
	"Cycle Active."
]

# ✅ Override support (event messages like Threshold reached)
var _system_log_override_time: float = 0.0

func _ready() -> void:
	# ✅ Let Board call us: get_tree().call_group("hud", "push_system_log", ...)
	add_to_group("hud")

	btn_end.pressed.connect(func() -> void:
		emit_signal("end_round_pressed")
	)

	# Captions
	cap_energy.text = "Cycle"
	cap_stored.text = "Reserve"

	# Default stat values
	set_energy(0.0)
	set_bank_energy(0.0)
	set_multiplier(1.0)

	# Milestone default
	lbl_goal_title.text = "NEXT TARGET"
	lbl_goal_main.text = "—"
	lbl_goal_sub.text = ""
	_last_goal_main = lbl_goal_main.text
	_last_goal_sub = lbl_goal_sub.text

	_goal_card_base_scale = goal_card.scale

	# System log init (Phase 1 safe)
	if lbl_system_log != null:
		lbl_system_log.text = _system_log_lines[0] if not _system_log_lines.is_empty() else ""
		lbl_system_log.modulate.a = system_log_alpha
		_system_log_accum = 0.0

	# Start timer (Main will override this with the real effective duration)
	start_round(round_duration_sec)

func bind_goal_sources(board: Board, spawner: Spawner, db: ShapeDB) -> void:
	_board = board
	_spawner = spawner
	_shape_db = db

	_goal_accum = 999.0 # force immediate refresh
	_update_goal_text()

# ✅ Main calls this to enable/disable timer
func set_timer_enabled(enabled: bool) -> void:
	_timer_enabled = enabled

	if round_bar != null:
		round_bar.visible = enabled

	# If disabling timer mid-cycle, stop countdown immediately (no auto end)
	if not enabled:
		_running = false
		_time_left = 0.0
		if round_bar != null:
			round_bar.value = 0.0

func start_round(duration_sec: float) -> void:
	# If timer disabled, keep bar hidden and never start countdown
	if not _timer_enabled:
		_running = false
		_time_left = 0.0
		if round_bar != null:
			round_bar.visible = false
			round_bar.value = 0.0
		return

	round_duration_sec = max(1.0, duration_sec)
	_time_left = round_duration_sec
	_running = true

	if round_bar != null:
		round_bar.visible = true
		round_bar.min_value = 0.0
		round_bar.max_value = round_duration_sec
		round_bar.value = round_duration_sec

func stop_round() -> void:
	_running = false
	_time_left = 0.0
	if round_bar != null:
		round_bar.value = 0.0

func _process(delta: float) -> void:
	# timer
	if _timer_enabled and _running:
		_time_left -= delta
		if _time_left <= 0.0:
			_time_left = 0.0
			_running = false
			if round_bar != null:
				round_bar.value = 0.0
			emit_signal("end_round_pressed")
		else:
			if round_bar != null:
				round_bar.value = _time_left

	# goal refresh
	_goal_accum += delta
	if _goal_accum >= goal_update_interval:
		_goal_accum = 0.0
		_update_goal_text()

	# ✅ system log rotation / override
	if lbl_system_log != null and not _system_log_lines.is_empty():
		_tick_system_log(delta)

func set_energy(energy: float) -> void:
	lbl_energy.text = _fmt(energy)

func set_bank_energy(energy: float) -> void:
	lbl_stored.text = _fmt(energy)

func _fmt(v: float) -> String:
	if v >= 1000000.0:
		return "%0.2fM" % (v / 1000000.0)
	if v >= 1000.0:
		return "%0.2fK" % (v / 1000.0)
	return "%0.0f" % v

func set_multiplier(mult: float) -> void:
	lbl_mult.text = "%0.2f" % mult

# -------------------------
# System Log Helpers
# -------------------------

func push_system_log(line: String, hold_sec: float = 2.5) -> void:
	if lbl_system_log == null:
		return

	_system_log_override_time = max(0.5, hold_sec)
	_system_log_accum = 0.0

	if _system_log_tween != null and is_instance_valid(_system_log_tween):
		_system_log_tween.kill()

	lbl_system_log.text = line
	lbl_system_log.modulate.a = 0.0

	_system_log_tween = create_tween()
	_system_log_tween.tween_property(lbl_system_log, "modulate:a", system_log_alpha, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _tick_system_log(delta: float) -> void:
	if lbl_system_log == null or _system_log_lines.is_empty():
		return

	if _system_log_override_time > 0.0:
		_system_log_override_time -= delta
		return

	_system_log_accum += delta
	if _system_log_accum < system_log_interval:
		return
	_system_log_accum = 0.0

	_rotate_system_log()

func _rotate_system_log() -> void:
	if lbl_system_log == null or _system_log_lines.is_empty():
		return

	_system_log_index = (_system_log_index + 1) % _system_log_lines.size()
	var next_text: String = _system_log_lines[_system_log_index]

	if _system_log_tween != null and is_instance_valid(_system_log_tween):
		_system_log_tween.kill()

	_system_log_tween = create_tween()

	_system_log_tween.tween_property(lbl_system_log, "modulate:a", 0.0, system_log_fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_system_log_tween.tween_callback(func() -> void:
		lbl_system_log.text = next_text
	)

	_system_log_tween.tween_property(lbl_system_log, "modulate:a", system_log_alpha, system_log_fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# -------------------------
# Goal Logic
# -------------------------
func _update_goal_text() -> void:
	if _board == null or _spawner == null or _shape_db == null:
		_set_goal_text("—", "")
		return

	var active_type: int = 0
	if "active_spawn_shape_type" in _spawner:
		active_type = int(_spawner.get("active_spawn_shape_type"))

	var cps: int = 10
	if "colors_per_shape" in _shape_db:
		cps = max(int(_shape_db.get("colors_per_shape")), 1)

	var counts: Dictionary = {}
	var highest_seen: int = -1

	var shapes_container: Node = _board.get_node_or_null("ShapesContainer")
	if shapes_container == null:
		_set_goal_text("—", "")
		return

	for child in shapes_container.get_children():
		if child is Shape:
			var s: Shape = child as Shape
			if s.shape_type_index != active_type:
				continue

			var r: int = int(s.color_rank)
			highest_seen = max(highest_seen, r)

			if not counts.has(r):
				counts[r] = 0
			counts[r] = int(counts[r]) + 1

	if highest_seen < 0:
		_set_goal_text("Build your first shape", "Drag & merge two matching ones")
		return

	var merge_rank: int = -1
	for r in range(highest_seen, -1, -1):
		if counts.has(r) and int(counts[r]) >= 2:
			merge_rank = r
			break

	var shape_name: String = _shape_name(active_type)

	if merge_rank >= 0:
		if merge_rank >= cps - 1:
			var next_type_name: String = _shape_name(active_type + 1)
			_set_goal_text(
				"Merge 2 %s %ss" % [_rank_name(merge_rank), shape_name],
				"Unlocks: %s (Rank 0)" % next_type_name
			)
		else:
			_set_goal_text(
				"Merge 2 %s %ss" % [_rank_name(merge_rank), shape_name],
				"Next: %s %s" % [_rank_name(merge_rank + 1), shape_name]
			)
	else:
		_set_goal_text(
			"Make another %s %s" % [_rank_name(highest_seen), shape_name],
			"So you can merge"
		)

func _set_goal_text(main: String, sub: String) -> void:
	if main == _last_goal_main and sub == _last_goal_sub:
		return

	lbl_goal_main.text = main
	lbl_goal_sub.text = sub

	_last_goal_main = main
	_last_goal_sub = sub

	_play_goal_bump()

func _play_goal_bump() -> void:
	if goal_card == null:
		return

	if _goal_tween != null and is_instance_valid(_goal_tween):
		_goal_tween.kill()
	_goal_tween = create_tween()

	lbl_goal_main.modulate.a = 0.0
	lbl_goal_sub.modulate.a = 0.0

	_goal_tween.tween_property(lbl_goal_main, "modulate:a", 1.0, goal_fade_time)
	_goal_tween.tween_property(lbl_goal_sub, "modulate:a", 1.0, goal_fade_time)

	goal_card.scale = _goal_card_base_scale
	_goal_tween.tween_property(goal_card, "scale", _goal_card_base_scale * goal_pop_scale, goal_pop_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_goal_tween.tween_property(goal_card, "scale", _goal_card_base_scale, goal_pop_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _rank_name(rank: int) -> String:
	if "color_rank_names" in _shape_db:
		var arr: Array = _shape_db.get("color_rank_names")
		if arr != null and rank >= 0 and rank < arr.size():
			var v = arr[rank]
			if v != null and str(v) != "":
				return str(v)
	return "Rank %d" % rank

func _shape_name(type_index: int) -> String:
	if "shape_types" in _shape_db:
		var st: Array = _shape_db.get("shape_types")
		if st != null and type_index >= 0 and type_index < st.size():
			var def = st[type_index]

			if def != null and "display_name" in def:
				var dn = def.get("display_name")
				if dn != null and str(dn) != "":
					return str(dn)

			if def != null and "id" in def:
				var sid = def.get("id")
				if sid != null and str(sid) != "":
					return str(sid)

	return "Shape"
