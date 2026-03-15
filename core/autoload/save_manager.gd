extends Node
class_name SaveManager

const SAVE_PATH: String = "user://lumina_save.json"

func save_game(data: Dictionary) -> void:
	var json_text: String = JSON.stringify(data)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open save file for writing.")
		return
	f.store_string(json_text)
	f.flush()
	f.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("Failed to open save file for reading.")
		return {}

	var text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed as Dictionary
