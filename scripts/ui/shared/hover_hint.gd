extends Control
class_name HoverHint

@export_multiline var hover_text: String = ""
@export var hover_title: String = ""
@export_enum("Info", "Danger", "Upgrade") var hover_style: int = 0
@export var hover_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if HoverCardGlobal != null:
		HoverCardGlobal.hide_card_immediate()

func _on_mouse_entered() -> void:
	if hover_text.strip_edges().is_empty():
		return
	HoverCardGlobal.show_card(hover_text, self, hover_offset, hover_title, hover_style)

func _on_mouse_exited() -> void:
	HoverCardGlobal.hide_card()
