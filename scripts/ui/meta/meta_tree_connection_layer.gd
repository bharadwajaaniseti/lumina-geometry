extends Control
class_name MetaTreeConnectionLayer

var connections: Array[Dictionary] = []

@export var locked_line_color: Color = Color("CFC7DD")
@export var available_line_color: Color = Color("A88AD8")
@export var owned_line_color: Color = Color("6B2FA3")
@export var line_width: float = 4.0

func set_connections(new_connections: Array[Dictionary]) -> void:
	connections = new_connections
	queue_redraw()

func _draw() -> void:
	for item in connections:
		var from_pos: Vector2 = item.get("from", Vector2.ZERO)
		var to_pos: Vector2 = item.get("to", Vector2.ZERO)
		var state: String = str(item.get("state", "locked"))

		var color := locked_line_color
		match state:
			"owned":
				color = owned_line_color
			"available":
				color = available_line_color
			_:
				color = locked_line_color

		draw_line(from_pos, to_pos, color, line_width, true)
