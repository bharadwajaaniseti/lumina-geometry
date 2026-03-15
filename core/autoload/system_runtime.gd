extends Node
class_name SystemRuntime

const ECONOMY_SCRIPT := preload("res://systems/phase_1/economy.gd")

signal runtime_started
signal runtime_stopped
signal economy_created
signal economy_reset
signal runtime_banked(raw_amount: float, reserve_amount: float)

## Time between auto-bank steps while Always-Run is active.
@export var auto_bank_interval_sec: float = 0.50

## How often Runtime auto-saves.
@export var auto_save_interval_sec: float = 1.0

## When true, bank everything currently in live cycle energy every bank tick.
@export var bank_all_available_energy: bool = true

## Used only if bank_all_available_energy is false.
@export var bank_step_amount: float = 100.0

@export_group("Background Production")
## Base raw energy/sec generated while Phase1 is NOT active and Always-Run is unlocked.
## This is the backbone of off-screen production.
@export var background_base_eps: float = 1.0

## Extra raw energy/sec added per Spawn Rate level while off-screen.
@export var background_spawn_rate_eps_per_level: float = 0.35

## Extra raw energy/sec added per Tier Boost level while off-screen.
@export var background_tier_eps_per_level: float = 0.60

## Extra raw energy/sec added per Auto Interval level while off-screen.
@export var background_interval_eps_per_level: float = 0.75

## Extra raw energy/sec added per Auto Range level while off-screen.
@export var background_range_eps_per_level: float = 0.45

## Multiplies all off-screen production.
@export var background_global_multiplier: float = 1.0

var active: bool = false
var economy: Economy = null

var _auto_bank_accum: float = 0.0
var _auto_save_accum: float = 0.0
var _phase1_attached: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -10
	_ensure_economy()

func _ensure_economy() -> Economy:
	if economy != null and is_instance_valid(economy):
		return economy

	economy = ECONOMY_SCRIPT.new() as Economy
	economy.name = "RuntimeEconomy"
	add_child(economy)
	economy_created.emit()
	return economy

func get_or_create_economy() -> Economy:
	return _ensure_economy()

func has_economy() -> bool:
	return economy != null and is_instance_valid(economy)

func is_running() -> bool:
	return active

func set_phase1_attached(value: bool) -> void:
	_phase1_attached = value

func is_phase1_attached() -> bool:
	return _phase1_attached

func start_runtime() -> Economy:
	var econ: Economy = _ensure_economy()
	active = true
	runtime_started.emit()
	return econ

func stop_runtime() -> void:
	active = false
	runtime_stopped.emit()

func begin_new_round() -> Economy:
	var econ: Economy = _ensure_economy()
	econ.reset_for_new_round()
	_auto_bank_accum = 0.0
	_auto_save_accum = 0.0
	active = true
	economy_reset.emit()
	runtime_started.emit()
	return econ

func reset_runtime() -> void:
	active = false
	var econ: Economy = _ensure_economy()
	econ.reset_for_new_round()
	_auto_bank_accum = 0.0
	_auto_save_accum = 0.0
	_phase1_attached = false
	economy_reset.emit()
	runtime_stopped.emit()

func _process(delta: float) -> void:
	if not active:
		return

	var econ: Economy = _ensure_economy()
	if econ == null:
		return

	# Always tick live economy.
	econ.tick(delta)

	# If Phase1 is not open, simulate abstract background automation.
	if Game_State.always_run_unlocked() and not _phase1_attached:
		var bg_eps: float = _get_background_eps()
		if bg_eps > 0.0:
			econ.add_energy(bg_eps * delta * econ.get_run_multiplier())

	# Auto-bank in Always-Run mode so Reserve remains live across scenes.
	if Game_State.always_run_unlocked():
		_auto_bank_accum += delta
		while _auto_bank_accum >= auto_bank_interval_sec:
			_auto_bank_accum -= auto_bank_interval_sec
			_auto_bank_live_energy()

	_auto_save_accum += delta
	if _auto_save_accum >= auto_save_interval_sec:
		_auto_save_accum = 0.0
		Game_State.save_to_disk()

func _get_background_eps() -> float:
	var eps: float = background_base_eps

	eps += float(Game_State.get_level(Game_State.IDS.SPAWN_RATE)) * background_spawn_rate_eps_per_level
	eps += float(Game_State.get_level(Game_State.IDS.TIER2_CHANCE)) * background_tier_eps_per_level
	eps += float(Game_State.get_level(Game_State.IDS.AUTO_INTERVAL)) * background_interval_eps_per_level
	eps += float(Game_State.get_level(Game_State.IDS.AUTO_RANGE)) * background_range_eps_per_level

	eps *= background_global_multiplier
	return max(eps, 0.0)

func _auto_bank_live_energy() -> void:
	var econ: Economy = _ensure_economy()
	if econ == null:
		return

	var raw_amount: float = 0.0

	if bank_all_available_energy:
		raw_amount = econ.extract_all_energy()
	else:
		raw_amount = econ.extract_energy(bank_step_amount)

	if raw_amount <= 0.0:
		return

	var reserve_amount: float = raw_amount * Game_State.deposit_mult()
	Game_State.deposit_run_energy(reserve_amount)
	runtime_banked.emit(raw_amount, reserve_amount)
