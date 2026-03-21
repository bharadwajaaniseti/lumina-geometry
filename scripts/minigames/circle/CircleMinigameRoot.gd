extends Node2D

func _ready():
	center_on_screen()

	# Listen for resize
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized():
	center_on_screen()

func center_on_screen():
	var viewport_size = get_viewport_rect().size
	position = viewport_size * 0.5
