extends Node
class_name ScoreManager

@export var base_points_per_merge: float = 10.0
@export var tier_bonus_factor: float = 1.35
@export var motion_bonus: float = 1.10
@export var points_per_second: float = 0.0

@export var spm_smoothing: float = 0.12

var _run_score: float = 0.0
var _best_run: float = 0.0
var _elapsed: float = 0.0
var _spm_smoothed: float = 0.0

func reset_for_new_round() -> void:
	_run_score = 0.0
	_elapsed = 0.0
	_spm_smoothed = 0.0

func tick(delta: float) -> void:
	_elapsed += delta

	if points_per_second > 0.0:
		add_score(points_per_second * delta)

	var spm_instant: float = 0.0
	if _elapsed > 0.01:
		spm_instant = (_run_score / _elapsed) * 60.0

	_spm_smoothed = lerp(_spm_smoothed, spm_instant, spm_smoothing)

func add_score(amount: float) -> void:
	if amount <= 0.0:
		return
	_run_score += amount

# Called by board.gd on merge
func on_merge(tier: int, motion_type: int) -> void:
	var t: int = max(1, tier)
	var tier_mult: float = pow(tier_bonus_factor, float(t - 1))

	var m_mult: float = 1.0
	if motion_type == 1:
		m_mult = motion_bonus
	elif motion_type == 2:
		m_mult = motion_bonus
	elif motion_type == 3:
		m_mult = motion_bonus * 1.05

	add_score(base_points_per_merge * tier_mult * m_mult)

# Called by board.gd when higher tiers appear (optional reward)
func on_new_tier_spawned(tier: int) -> void:
	if tier >= 5:
		add_score(5.0 * float(tier))

func finalize_round() -> void:
	if _run_score > _best_run:
		_best_run = _run_score

func get_run_score() -> float:
	return _run_score

func get_best_run() -> float:
	return _best_run

func get_spm() -> float:
	return _spm_smoothed
