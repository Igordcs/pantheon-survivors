extends Resource
class_name ItemData

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var mythology: StringName
@export var icon: Texture2D
@export var price: int
@export var effect_id: StringName
@export var value: float
@export var secondary_value: float
@export var is_fundamental: bool = false
@export var max_level: int = 1
@export var level_values: Array[float] = []
@export var level_descriptions: Array[String] = []


func get_value_for_level(level: int) -> float:
	if level_values.is_empty():
		return value
	return level_values[clampi(level - 1, 0, level_values.size() - 1)]


func get_level_description(level: int) -> String:
	if level_descriptions.is_empty():
		return description
	return level_descriptions[clampi(level - 1, 0, level_descriptions.size() - 1)]
