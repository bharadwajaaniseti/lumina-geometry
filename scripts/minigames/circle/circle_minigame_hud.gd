extends Control

@onready var shards_label: Label = $MarginContainer/Label

func set_shards(value: int) -> void:
	shards_label.text = "Shards: %d" % value
