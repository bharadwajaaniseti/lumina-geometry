extends Resource
class_name InventoryShapeDB

@export var shapes: Array[InventoryShapeDef] = []

func size() -> int:
	return shapes.size()

func is_valid_index(index: int) -> bool:
	return index >= 0 and index < shapes.size()

func get_shape(index: int) -> InventoryShapeDef:
	if not is_valid_index(index):
		return null
	return shapes[index]

func get_shape_by_id(shape_id: String) -> InventoryShapeDef:
	for shape in shapes:
		if shape != null and shape.id == shape_id:
			return shape
	return null

func find_index_by_id(shape_id: String) -> int:
	for i in range(shapes.size()):
		var shape := shapes[i]
		if shape != null and shape.id == shape_id:
			return i
	return -1
