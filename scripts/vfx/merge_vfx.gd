extends Node2D
class_name MergeVFX

@onready var ring: Line2D = $Ring

var _life: float = 0.22
var _t: float = 0.0
var _start_r: float = 14.0
var _end_r: float = 80.0
var _color: Color = Color.WHITE

func setup(color: Color, start_r: float = 14.0, end_r: float = 80.0, life: float = 0.22) -> void:
	_color = color
	_start_r = start_r
	_end_r = end_r
	_life = life
	_t = 0.0
	_draw_ring(_start_r, 1.0)

func _process(delta: float) -> void:
	_t += delta
	var p: float = clamp(_t / _life, 0.0, 1.0)

	# ease-out
	var e: float = 1.0 - pow(1.0 - p, 3.0)

	var r: float = lerp(_start_r, _end_r, e)
	var a: float = lerp(0.95, 0.0, p)

	_draw_ring(r, a)

	if _t >= _life:
		queue_free()

func _draw_ring(radius: float, alpha: float) -> void:
	if ring == null:
		return

	var pts := PackedVector2Array()
	var steps: int = 48
	for i in range(steps + 1):
		var ang: float = TAU * float(i) / float(steps)
		pts.append(Vector2(cos(ang), sin(ang)) * radius)

	ring.points = pts
	ring.default_color = Color(_color.r, _color.g, _color.b, alpha)
