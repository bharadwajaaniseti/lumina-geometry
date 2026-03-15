extends Control
class_name RoundEndModal

signal continue_pressed
signal upgrades_pressed

@export var mainmenu_scene: String = "res://scenes/menu/Menu.tscn"

@export var pause_game_when_open: bool = true
@export var max_visible_ranks: int = 7

# Colors (sterile report)
@export var header_color: Color = Color("#ff6b6b")
@export var subtitle_color: Color = Color("#8b9099")
@export var section_color: Color = Color("#c44f4f")
@export var number_color: Color = Color("#6d79ff")
@export var status_color: Color = Color("#7a6b9a")
@export var highlight_color: Color = Color("#2f7dff")

# Cell sizing
@export var label_col_width: float = 72.0
@export var cell_min_width: float = 44.0
@export var rank_font_size: int = 12
@export var value_font_size: int = 14
@export var label_font_size: int = 12

@export var default_cycle_index: int = 1

# --- Subtle number animation ---
@export var numbers_anim_enabled: bool = true
@export var numbers_anim_time: float = 0.30
@export var numbers_anim_stagger: float = 0.025
@export var numbers_anim_trans: Tween.TransitionType = Tween.TRANS_SINE
@export var numbers_anim_ease: Tween.EaseType = Tween.EASE_OUT

@onready var dimmer: ColorRect = $Dimmer
@onready var card: Control = $Center/Card

@onready var lbl_title: Label = $Center/Card/Margin/VBox/Header/HBoxContainer/Title
@onready var lbl_subtitle: Label = $Center/Card/Margin/VBox/Header/Subtitle
@onready var lbl_highlight: Label = $Center/Card/Margin/VBox/Header/Highlight

@onready var lbl_dist_title: Label = $Center/Card/Margin/VBox/Dist/DistTitle
@onready var row_rank: HBoxContainer = $Center/Card/Margin/VBox/Dist/RankRow
@onready var row_count: HBoxContainer = $Center/Card/Margin/VBox/Dist/CountRow
@onready var row_output: HBoxContainer = $Center/Card/Margin/VBox/Dist/OutputRow

@onready var lbl_merges: Label = $Center/Card/Margin/VBox/Summary/SummaryLine1/Merges
@onready var lbl_out: Label = $Center/Card/Margin/VBox/Summary/SummaryLine1/Out
@onready var lbl_eff: Label = $Center/Card/Margin/VBox/Summary/SummaryLine1/Eff
@onready var lbl_transfer: Label = $Center/Card/Margin/VBox/Summary/SummaryLine2/Transfer
@onready var lbl_reserve: Label = $Center/Card/Margin/VBox/Summary/SummaryLine2/Reserve

@onready var lbl_status: Label = $Center/Card/Margin/VBox/Status
@onready var btn_upgrades: Button = $Center/Card/Margin/VBox/Buttons/UpgradesBtn
@onready var btn_continue: Button = $Center/Card/Margin/VBox/Buttons/ContinueBtn

var _open_tween: Tween = null
var _numbers_tween: Tween = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	btn_upgrades.pressed.connect(func() -> void:
		upgrades_pressed.emit()
	)
	btn_continue.pressed.connect(func() -> void:
		continue_pressed.emit()
		close()
	)

	# Static text + styling
	lbl_title.text = "CYCLE REPORT"
	lbl_title.add_theme_color_override("font_color", header_color)
	lbl_subtitle.add_theme_color_override("font_color", subtitle_color)

	lbl_highlight.text = ""
	lbl_highlight.visible = false
	lbl_highlight.add_theme_color_override("font_color", highlight_color)

	lbl_dist_title.text = "PROGRESSION BREAKDOWN"
	lbl_dist_title.add_theme_color_override("font_color", section_color)

	lbl_status.text = "System Stability: Within Parameters."
	lbl_status.add_theme_color_override("font_color", status_color)

	# Summary labels muted (we’ll rewrite text to human-readable)
	var metric_color := Color("#9aa3b2")
	lbl_merges.add_theme_color_override("font_color", metric_color)
	lbl_out.add_theme_color_override("font_color", metric_color)
	lbl_eff.add_theme_color_override("font_color", metric_color)
	lbl_transfer.add_theme_color_override("font_color", metric_color)
	lbl_reserve.add_theme_color_override("font_color", metric_color)

func open(summary: Dictionary) -> void:
	_build_report(summary)

	visible = true
	if pause_game_when_open:
		get_tree().paused = true

	_play_open_anim()

func close() -> void:
	if not visible:
		return
	_play_close_anim()

# -------------------------
# Build Report
# -------------------------
func _build_report(summary: Dictionary) -> void:
	_kill_numbers_tween()

	# Subtitle
	var cycle_idx: int = int(summary.get("cycle_index", default_cycle_index))
	lbl_subtitle.text = "Cycle %02d - Calibration Analysis" % cycle_idx

	# Highlight line (optional)
	var hl: String = str(summary.get("highlight", ""))
	if hl.strip_edges() != "":
		lbl_highlight.text = hl
		lbl_highlight.visible = true
	else:
		lbl_highlight.text = ""
		lbl_highlight.visible = false

	# Rank names (optional): ["Orange","Green","Blue"...]
	var rank_names: Array = summary.get("rank_names", [])

	# Extract rows: array of { tier, merged, energy }
	var rows: Array = summary.get("rows", [])

	# Build per-rank aggregates (rank = tier-1)
	var counts_by_rank: Dictionary = {}
	var output_by_rank: Dictionary = {}

	var total_merges: int = 0
	var total_output: float = 0.0
	var highest_rank: int = -1

	for v in rows:
		if not (v is Dictionary):
			continue
		var d := v as Dictionary

		var tier: int = int(d.get("tier", 1))
		var rank: int = max(tier - 1, 0) # fallback

		var db: ShapeDB = summary.get("shape_db", null)
		if db != null:
			var decoded: Dictionary = db.decode_global_tier(tier)
			rank = int(decoded.get("color_rank", rank))

		var merged: int = int(d.get("merged", 0))
		var outv: float = float(d.get("energy", 0.0))

		if merged <= 0 and outv <= 0.0:
			continue

		highest_rank = max(highest_rank, rank)

		counts_by_rank[rank] = int(counts_by_rank.get(rank, 0)) + merged
		output_by_rank[rank] = float(output_by_rank.get(rank, 0.0)) + outv

		total_merges += merged
		total_output += outv

	var deposit_energy: float = float(summary.get("deposit_energy", 0.0))

	if total_merges <= 0 and total_output <= 0.0:
		_render_empty_matrix(rank_names)
		_set_summaries(0, 0.0, deposit_energy)
		return

	var max_rank_to_show: int = max(highest_rank, 0)
	var visible_count: int = min(max_visible_ranks, max_rank_to_show + 1)
	visible_count = max(1, visible_count)

	var hidden_count: int = (max_rank_to_show + 1) - visible_count
	hidden_count = max(hidden_count, 0)

	_render_matrix(counts_by_rank, output_by_rank, visible_count, hidden_count, rank_names)
	_set_summaries(total_merges, total_output, deposit_energy)

func _render_empty_matrix(rank_names: Array) -> void:
	_clear_row(row_rank)
	_clear_row(row_count)
	_clear_row(row_output)

	# First column labels
	_add_row_label(row_rank, "")
	_add_row_label(row_count, "Count")
	_add_row_label(row_output, "Energy")

	# One rank col
	_add_rank_header(row_rank, 0, rank_names)
	var c := _add_cell(row_count, "0", value_font_size, number_color, true)
	var o := _add_cell(row_output, "0", value_font_size, number_color, true)

	if numbers_anim_enabled:
		_start_numbers_tween()
		_tween_int_label(c, 0, 0.0, "")
		_tween_int_label(o, 0, 0.0, "")

func _render_matrix(counts_by_rank: Dictionary, output_by_rank: Dictionary, visible_count: int, hidden_count: int, rank_names: Array) -> void:
	_clear_row(row_rank)
	_clear_row(row_count)
	_clear_row(row_output)

	# Row labels
	_add_row_label(row_rank, "")
	_add_row_label(row_count, "Count")
	_add_row_label(row_output, "Energy")

	if numbers_anim_enabled:
		_start_numbers_tween()

	for r in range(0, visible_count):
		_add_rank_header(row_rank, r, rank_names)

		var c_val: int = int(counts_by_rank.get(r, 0))
		var o_val: int = int(round(output_by_rank.get(r, 0.0)))

		var c_lbl := _add_cell(row_count, "0" if numbers_anim_enabled else str(c_val), value_font_size, number_color, true)
		var o_lbl := _add_cell(row_output, "0" if numbers_anim_enabled else str(o_val), value_font_size, number_color, true)

		if numbers_anim_enabled:
			var delay := float(r) * numbers_anim_stagger
			_tween_int_label(c_lbl, c_val, delay, "")
			_tween_int_label(o_lbl, o_val, delay, "")

	if hidden_count > 0:
		_add_cell(row_rank, "+%d" % hidden_count, rank_font_size, subtitle_color, true)
		_add_cell(row_count, "", value_font_size, number_color, true)
		_add_cell(row_output, "", value_font_size, number_color, true)

func _add_rank_header(row: HBoxContainer, rank: int, rank_names: Array) -> void:
	var txt := ""
	if rank_names != null and rank < rank_names.size():
		var name := str(rank_names[rank])
		if name.strip_edges() != "":
			txt = name
	if txt == "":
		# Fallback that still feels “system”
		txt = "Level %d" % (rank + 1)

	_add_cell(row, txt, rank_font_size, subtitle_color, true)

func _set_summaries(total_merges: int, total_output: float, deposit_energy: float) -> void:
	var eff: float = 0.0
	if total_merges > 0:
		eff = total_output / float(total_merges)

	# Make efficiency human: 1.18 -> 118%
	var eff_pct: int = int(round(eff * 100.0))

	var output_i: int = int(round(total_output))
	var gained_i: int = int(round(deposit_energy))

	var bank_before: float = float(Game_State.stored_energy)
	var total_i: int = int(round(bank_before + deposit_energy))

	# Human-readable labels (mix casual + system)
	if not numbers_anim_enabled:
		lbl_merges.text = "COMBINED %d" % total_merges
		lbl_out.text = "GENERATED %d" % output_i
		lbl_eff.text = "EFFICIENCY %d%%" % eff_pct
		lbl_transfer.text = "GAINED %d" % gained_i
		lbl_reserve.text = "TOTAL %d" % total_i
		return

	_start_numbers_tween()

	lbl_merges.text = "COMBINED 0"
	lbl_out.text = "GENERATED 0"
	lbl_eff.text = "EFFICIENCY 0%"
	lbl_transfer.text = "GAINED 0"
	lbl_reserve.text = "TOTAL 0"

	_tween_int_label(lbl_merges, total_merges, 0.00, "COMBINED ")
	_tween_int_label(lbl_out, output_i, 0.02, "GENERATED ")
	_tween_int_label(lbl_transfer, gained_i, 0.06, "GAINED ")
	_tween_int_label(lbl_reserve, total_i, 0.08, "TOTAL ")

	# efficiency as integer percent
	_tween_int_label(lbl_eff, eff_pct, 0.04, "EFFICIENCY ")
	# add % suffix by setting it after tween ends
	_numbers_tween.tween_callback(func() -> void:
		lbl_eff.text = "EFFICIENCY %d%%" % eff_pct
	).set_delay(0.04 + numbers_anim_time)

# -------------------------
# Number animation helpers
# (No lambdas inside tween_method to avoid indent/parser issues)
# -------------------------
func _apply_int_to_label(v: float, lbl: Label, prefix: String) -> void:
	lbl.text = "%s%d" % [prefix, int(round(v))]

func _start_numbers_tween() -> void:
	if _numbers_tween != null and is_instance_valid(_numbers_tween):
		return
	_numbers_tween = create_tween()
	_numbers_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

func _kill_numbers_tween() -> void:
	if _numbers_tween != null and is_instance_valid(_numbers_tween):
		_numbers_tween.kill()
	_numbers_tween = null

func _tween_int_label(lbl: Label, target: int, delay: float, prefix: String) -> void:
	if lbl == null:
		return
	if _numbers_tween == null:
		_start_numbers_tween()

	var cb: Callable = Callable(self, "_apply_int_to_label").bind(lbl, prefix)

	_numbers_tween.tween_method(
		cb,
		0.0,
		float(target),
		numbers_anim_time
	).set_delay(delay).set_trans(numbers_anim_trans).set_ease(numbers_anim_ease)

# -------------------------
# UI helpers
# -------------------------
func _clear_row(row: HBoxContainer) -> void:
	for ch in row.get_children():
		ch.queue_free()

func _add_row_label(row: HBoxContainer, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(label_col_width, 0.0)
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.add_theme_font_size_override("font_size", label_font_size)
	lbl.add_theme_color_override("font_color", subtitle_color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(lbl)
	return lbl

func _add_cell(row: HBoxContainer, text: String, font_size: int, color: Color, centered: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(cell_min_width, 0.0)
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if centered:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return lbl

# -------------------------
# Open animation
# -------------------------
func _play_open_anim() -> void:
	dimmer.modulate.a = 0.0
	card.modulate.a = 0.0
	card.scale = Vector2(0.94, 0.94)

	if _open_tween != null and is_instance_valid(_open_tween):
		_open_tween.kill()

	_open_tween = create_tween()
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	_open_tween.tween_property(dimmer, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_tween.parallel().tween_property(card, "scale", Vector2(1, 1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_close_anim() -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(dimmer, "modulate:a", 0.0, 0.10)
	tw.parallel().tween_property(card, "modulate:a", 0.0, 0.10)
	tw.parallel().tween_property(card, "scale", Vector2(0.96, 0.96), 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tw.finished.connect(func():
		visible = false
		if pause_game_when_open:
			get_tree().paused = false
	)


func _on_home_btn_pressed() -> void:
	print("Pressed Home Button")
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file(mainmenu_scene)
