extends Camera3D

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 27.0
	position = Vector3(0, 18, 20)
	rotation_degrees = Vector3(-45.0, 0, 0)
