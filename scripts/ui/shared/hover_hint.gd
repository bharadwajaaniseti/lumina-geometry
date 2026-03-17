extends Control
class_name HoverHint

@export_multiline var hover_text: String = ""
@export var hover_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if hover_text.strip_edges().is_empty():
		return
	HoverCardGlobal.show_card(hover_text, self, hover_offset)

func _on_mouse_exited() -> void:
	HoverCardGlobal.hide_card()
