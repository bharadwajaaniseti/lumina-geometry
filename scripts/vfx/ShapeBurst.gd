extends Node2D

@onready var particles: GPUParticles2D = $GPUParticles2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func setup(tex: Texture2D, color: Color) -> void:
	# Safety
	if tex == null:
		queue_free()
		return

	particles.texture = tex
	particles.modulate = color

	# --- Juice: tiny random variation each burst ---
	particles.amount = int(_rng.randi_range(14, 26))

	var mat: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
	if mat != null:
		mat.spread = _rng.randf_range(170.0, 230.0)
		mat.initial_velocity_min = _rng.randf_range(110.0, 160.0)
		mat.initial_velocity_max = _rng.randf_range(200.0, 280.0)
		mat.angular_velocity_min = _rng.randf_range(-180.0, -60.0)
		mat.angular_velocity_max = _rng.randf_range(60.0, 180.0)

		# Optional: slightly different gravity per burst (feels organic)
		mat.gravity = Vector3(0.0, _rng.randf_range(180.0, 260.0), 0.0)

	particles.restart()
	particles.emitting = true

	# Auto free after it finishes
	var wait_time: float = particles.lifetime + particles.preprocess
	await get_tree().create_timer(wait_time).timeout
	queue_free()
