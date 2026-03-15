extends Node2D
class_name Phase1

@export var base_round_duration_sec: float = 120.0
@export var stats_update_interval: float = 0.15
@export var base_auto_merge_interval_sec: float = 1.5
@export var base_auto_merge_max_distance: float = 110.0
@export var menu_scene: String = "res://scenes/menu/Menu.tscn"

@onready var board: Board = $Board
@onready var hud: HUD = $Hud
@onready var spawner: Spawner = $Spawner

@onready var round_end_modal: Control = $Hud/RoundEndModal
@onready var upgrades_modal: Control = $Hud/UpgradesModal

var economy: Economy

var _round_running: bool = false
var _stats_accum: float = 0.0
var _auto_merge_accum: float = 0.0
var _pending_deposit: float = 0.0
var _last_round_summary: Dictionary = {}
var _continuous_mode_last: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	Game_State.load_from_disk()

	economy = Runtime.get_or_create_economy()
	Runtime.set_phase1_attached(true)

	spawner.init(board, board.shape_scene)

	_validate_shape_db()
	_assign_shape_db_to_economy()
	board.init_systems(economy, spawner)
	hud.bind_goal_sources(board, spawner, spawner.shape_db)

	await get_tree().process_frame
	_push_avoid_rects_to_board()
	get_viewport().size_changed.connect(_push_avoid_rects_to_board)

	hud.end_round_pressed.connect(_on_end_round_pressed)

	if round_end_modal.has_signal("continue_pressed"):
		round_end_modal.connect("continue_pressed", Callable(self, "_on_round_continue_pressed"))
	if round_end_modal.has_signal("upgrades_pressed"):
		round_end_modal.connect("upgrades_pressed", Callable(self, "_on_round_upgrades_pressed"))

	if upgrades_modal.has_signal("closed"):
		upgrades_modal.connect("closed", Callable(self, "_on_upgrades_closed"))

	_refresh_hud_static_stats()
	Game_State.changed.connect(func() -> void:
		_refresh_hud_static_stats()
	)

	_apply_spawn_upgrades()
	Game_State.changed.connect(_apply_spawn_upgrades)

	Game_State.changed.connect(_apply_timer_mode_from_upgrades)
	_apply_timer_mode_from_upgrades()

	upgrades_modal.set("base_round_duration_sec", base_round_duration_sec)
	upgrades_modal.set("base_auto_merge_interval_sec", base_auto_merge_interval_sec)
	upgrades_modal.set("base_auto_merge_range_px", base_auto_merge_max_distance)

	if Runtime.is_running():
		_resume_runtime_round()
	else:
		start_round()

func _exit_tree() -> void:
	Runtime.set_phase1_attached(false)

	if not Game_State.always_run_unlocked():
		Runtime.stop_runtime()

func _validate_shape_db() -> void:
	var db: ShapeDB = spawner.shape_db
	if db == null:
		return

	var cps: int = db.colors_per_shape
	if cps <= 0:
		push_warning("ShapeDB configuration mismatch. colors_per_shape must be greater than 0.")

func _assign_shape_db_to_economy() -> void:
	if spawner == null:
		return
	if spawner.shape_db == null:
		return

	if economy == null:
		economy = Runtime.get_or_create_economy()

	if economy != null:
		economy.shape_db = spawner.shape_db

func _process(delta: float) -> void:
	if not _round_running:
		return

	# Economy ticking is owned by Runtime now.
	_stats_accum += delta
	if _stats_accum >= stats_update_interval:
		_stats_accum = 0.0
		hud.set_energy(economy.get_energy())
		hud.set_multiplier(economy.get_run_multiplier())

	if Game_State.automation_unlocked():
		var interval: float = Game_State.auto_merge_interval(base_auto_merge_interval_sec)
		var mergerange: float = base_auto_merge_max_distance + Game_State.auto_merge_range_bonus_px()

		_auto_merge_accum += delta
		if _auto_merge_accum >= interval:
			_auto_merge_accum = 0.0
			board.try_auto_merge(mergerange)
	else:
		_auto_merge_accum = 0.0

func start_round() -> void:
	_fade_in_ambience()
	Runtime.set_phase1_attached(true)
	_round_running = true
	_stats_accum = 0.0
	_auto_merge_accum = 0.0
	_pending_deposit = 0.0
	_last_round_summary = {}

	Game_State.increment_cycle()

	economy = Runtime.begin_new_round()
	_assign_shape_db_to_economy()
	board.init_systems(economy, spawner)

	_refresh_hud_static_stats()

	board.set_process(true)
	board.set_process_input(true)
	spawner.set_spawning_enabled(true)

	var effective_duration: float = base_round_duration_sec + Game_State.round_time_bonus_sec()
	_apply_timer_mode_from_upgrades()
	hud.start_round(effective_duration)
	_refresh_hud_static_stats()

func _resume_runtime_round() -> void:
	_fade_in_ambience()
	Runtime.set_phase1_attached(true)
	_round_running = true
	_stats_accum = 0.0
	_auto_merge_accum = 0.0

	economy = Runtime.get_or_create_economy()
	_assign_shape_db_to_economy()
	board.init_systems(economy, spawner)

	board.set_process(true)
	board.set_process_input(true)
	spawner.set_spawning_enabled(true)

	var effective_duration: float = base_round_duration_sec + Game_State.round_time_bonus_sec()
	_apply_timer_mode_from_upgrades()
	hud.start_round(effective_duration)

	_refresh_hud_static_stats()

func _apply_timer_mode_from_upgrades() -> void:
	var infinite_mode: bool = false

	if Game_State != null and Game_State.has_method("always_run_unlocked"):
		infinite_mode = bool(Game_State.call("always_run_unlocked"))
	else:
		var time_lvl: int = Game_State.get_level(Game_State.IDS.ROUND_TIME)
		var interval_lvl: int = Game_State.get_level(Game_State.IDS.AUTO_INTERVAL)
		var range_lvl: int = Game_State.get_level(Game_State.IDS.AUTO_RANGE)
		infinite_mode = (time_lvl >= 40 and interval_lvl >= 48 and range_lvl >= 10)

	if hud != null and hud.has_method("set_timer_enabled"):
		hud.set_timer_enabled(not infinite_mode)

	if hud != null and hud.btn_end != null:
		hud.btn_end.text = "Home" if infinite_mode else "End Cycle"

	if infinite_mode and not _continuous_mode_last:
		_continuous_mode_last = true
		if hud != null and hud.has_method("push_system_log"):
			hud.push_system_log("Continuous Mode Engaged.", 2.8)
	elif not infinite_mode:
		_continuous_mode_last = false

func _fade_in_ambience(duration: float = 2.0, target_db: float = -26.0) -> void:
	var ambience: AudioStreamPlayer = $Ambience
	ambience.volume_db = -80.0
	ambience.play()

	var tween := create_tween()
	tween.tween_property(
		ambience,
		"volume_db",
		target_db,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fade_out_ambience(duration: float = 1.5) -> void:
	var ambience: AudioStreamPlayer = $Ambience

	var tween := create_tween()
	tween.tween_property(
		ambience,
		"volume_db",
		-80.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func end_round(_reason: String = "manual") -> void:
	_fade_out_ambience()
	if not _round_running:
		return

	_round_running = false

	hud.stop_round()
	spawner.set_spawning_enabled(false)
	board.set_process_input(false)
	board.set_process(false)

	if not Game_State.always_run_unlocked():
		Runtime.stop_runtime()

	_pending_deposit = economy.get_energy()

	var summary: Dictionary = economy.build_round_summary()
	summary["shape_db"] = spawner.shape_db
	summary["cycle_index"] = Game_State.cycle_count

	var shown_deposit: float = _pending_deposit * Game_State.deposit_mult()
	summary["deposit_energy"] = shown_deposit
	summary["rank_names"] = _get_rank_names()
	summary["highlight"] = _build_cycle_highlight(summary)

	_unlock_inventory_shapes_from_summary(summary)

	_last_round_summary = summary.duplicate(true)
	round_end_modal.call("open", summary)

func _deposit_if_needed() -> void:
	if _pending_deposit <= 0.0:
		return

	var amount := _pending_deposit * Game_State.deposit_mult()
	Game_State.deposit_run_energy(amount)

	# Remove the deposited live energy from runtime economy too.
	if economy != null and is_instance_valid(economy):
		economy.extract_energy(_pending_deposit)

	_pending_deposit = 0.0
	Game_State.save_to_disk()

func _on_end_round_pressed() -> void:
	if Game_State.always_run_unlocked():
		get_tree().change_scene_to_file(menu_scene)
		return

	end_round("hud_or_timer")

func _on_round_continue_pressed() -> void:
	_deposit_if_needed()
	spawner.set_spawning_enabled(false)
	board.clear_all_shapes()
	start_round()

func _on_round_upgrades_pressed() -> void:
	_deposit_if_needed()
	round_end_modal.call("close")
	upgrades_modal.call("open")

func _on_upgrades_closed() -> void:
	if _last_round_summary.size() > 0:
		_last_round_summary["deposit_energy"] = 0.0
		_last_round_summary["highlight"] = "System Adjustments Applied."
	round_end_modal.call("open", _last_round_summary)

func _apply_spawn_upgrades() -> void:
	spawner.set_spawn_rate_multiplier(Game_State.spawn_speed_mult())
	spawner.direct_tier2_chance = Game_State.tier2_chance()

func _push_avoid_rects_to_board() -> void:
	var rects: Array[Rect2] = []

	var top_hbox: Control = hud.get_node_or_null("TopBar/HBox") as Control
	if top_hbox != null:
		rects.append(top_hbox.get_global_rect())
	else:
		var top_bar: Control = hud.get_node_or_null("TopBar") as Control
		if top_bar != null:
			rects.append(top_bar.get_global_rect())

	board.set_avoid_rects(rects)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game_State.save_to_disk()
		get_tree().quit()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEDOWN:
			print("DEV RESET (PageDown)")

			Runtime.reset_runtime()
			Game_State.reset_to_defaults()
			Game_State.save_to_disk()

			_pending_deposit = 0.0
			_last_round_summary = {}

			spawner.set_spawning_enabled(false)
			board.clear_all_shapes()

			_apply_spawn_upgrades()
			_apply_timer_mode_from_upgrades()

			start_round()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_PAGEUP:
			var add_amount: float = 100000.0
			Game_State.stored_energy += add_amount
			Game_State.changed.emit()
			Game_State.save_to_disk()

			if hud != null and hud.has_method("push_system_log"):
				hud.call("push_system_log", "DEV: Reserve +%s" % hud._fmt(add_amount), 2.0)

			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_HOME:
			for id in Game_State.IDS.values():
				var max_lvl: int = Game_State.get_max_level(id)
				if max_lvl < 0:
					Game_State.upgrades[id] = 25
				else:
					Game_State.upgrades[id] = max_lvl

			Game_State.changed.emit()
			Game_State.save_to_disk()

			_apply_spawn_upgrades()
			_apply_timer_mode_from_upgrades()

			if hud != null and hud.has_method("push_system_log"):
				hud.call("push_system_log", "DEV: Upgrades maximized.", 2.0)

			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_END:
			Game_State.stored_energy = 1_000_000_000.0
			Game_State.changed.emit()
			Game_State.save_to_disk()

			if hud != null and hud.has_method("push_system_log"):
				hud.call("push_system_log", "DEV: Reserve set to 1B.", 2.0)

			get_viewport().set_input_as_handled()
			return

func _get_rank_names() -> Array:
	if spawner != null and spawner.shape_db != null:
		if "color_rank_names" in spawner.shape_db:
			var arr: Array = spawner.shape_db.get("color_rank_names")
			if arr != null and arr.size() > 0:
				return arr.duplicate(true)
	return []

func _build_cycle_highlight(summary: Dictionary) -> String:
	var db: ShapeDB = spawner.shape_db
	if db == null:
		return ""

	var cps: int = max(db.colors_per_shape, 1)
	var rows: Array = summary.get("rows", [])

	var did_unlock: bool = false
	var unlocked_next_type: int = -1
	var peak_color_rank: int = -1

	for v in rows:
		if not (v is Dictionary):
			continue
		var d := v as Dictionary

		var merged: int = int(d.get("merged", 0))
		if merged <= 0:
			continue

		var tier: int = int(d.get("tier", 1))
		var decoded: Dictionary = db.decode_global_tier(tier)
		var st: int = int(decoded.get("shape_type", 0))
		var cr: int = int(decoded.get("color_rank", 0))

		peak_color_rank = max(peak_color_rank, cr)

		if cr == cps - 1:
			did_unlock = true
			unlocked_next_type = st + 1

		if did_unlock:
			if unlocked_next_type < 0 or unlocked_next_type >= db.shape_types.size():
				return "Max Shape Tier Reached."

			return "Shape Index Increased. Unlocked: %s" % _shape_name_from_db(unlocked_next_type)

	if peak_color_rank >= 0:
		return "Peak: %s" % db.get_color_rank_name(peak_color_rank)

	return "No merges this cycle."

func _shape_name_from_db(type_index: int) -> String:
	if spawner == null or spawner.shape_db == null:
		return "New Shape"

	var db: ShapeDB = spawner.shape_db

	if db.shape_types != null and type_index >= 0 and type_index < db.shape_types.size():
		var def: Resource = db.shape_types[type_index] as Resource
		if def != null:
			var dn = def.get("display_name")
			if dn != null and str(dn).strip_edges() != "":
				return str(dn)

			var sid = def.get("id")
			if sid != null and str(sid).strip_edges() != "":
				return str(sid)

	if db.tier_textures != null:
		var cps: int = max(db.colors_per_shape, 1)
		var base_i: int = type_index * cps
		if base_i >= 0 and base_i < db.tier_textures.size():
			var tex: Texture2D = db.tier_textures[base_i]
			if tex != null:
				var path := tex.resource_path
				if path != "":
					return path.get_file().get_basename().capitalize()

	return "New Shape"

func _unlock_inventory_shapes_from_summary(summary: Dictionary) -> void:
	var db: ShapeDB = spawner.shape_db
	if db == null:
		return

	var cps: int = max(db.colors_per_shape, 1)
	var rows: Array = summary.get("rows", [])

	for v in rows:
		if not (v is Dictionary):
			continue

		var d := v as Dictionary
		var merged: int = int(d.get("merged", 0))
		if merged <= 0:
			continue

		var tier: int = int(d.get("tier", 1))
		var decoded: Dictionary = db.decode_global_tier(tier)
		var st: int = int(decoded.get("shape_type", 0))
		var cr: int = int(decoded.get("color_rank", 0))

		if cr == cps - 1:
			var unlocked_next_type: int = st + 1

			if db.shape_types == null:
				continue
			if unlocked_next_type < 0 or unlocked_next_type >= db.shape_types.size():
				continue

			var unlocked_name: String = _shape_name_from_db(unlocked_next_type)
			if unlocked_name.strip_edges() != "":
				Game_State.unlock_inventory_shape(unlocked_name)

func _refresh_hud_static_stats() -> void:
	hud.set_bank_energy(Game_State.stored_energy)

	if hud.has_method("set_cycle"):
		hud.set_cycle(Game_State.cycle_count)

	if economy != null:
		hud.set_multiplier(economy.get_run_multiplier())
		hud.set_energy(economy.get_energy())
