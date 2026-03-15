extends TextureButton
class_name InventoryShapeSlot

signal slot_pressed(slot_index: int)

@export var slot_index: int = -1
@export var slot_size: Vector2 = Vector2(100, 100)

@onready var icon: TextureRect = $Icon

func _ready() -> void:
	toggle_mode = true
	custom_minimum_size = slot_size

	if icon == null:
		push_error("InventoryShapeSlot: child node 'Icon' was not found.")
		return

	icon.visible = true
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1, 1, 1, 1)

	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func setup(index: int, texture: Texture2D, is_locked: bool) -> void:
	slot_index = index

	if icon != null:
		icon.texture = texture
		icon.visible = true
		icon.modulate = Color(1, 1, 1, 1)

	disabled = false
	visible = true

func set_selected(selected: bool) -> void:
	button_pressed = selected

func _on_pressed() -> void:
	slot_pressed.emit(slot_index)
