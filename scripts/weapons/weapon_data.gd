extends Resource
class_name WeaponData
## Dados configuráveis de uma arma.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var base_damage: float = 12.0
@export var cooldown: float = 2
@export var area: float = 250.0
@export var projectile_speed: float = 600.0
@export var projectile_count: int = 1
@export var max_level: int = 8
@export var levels: Array[WeaponLevelData] = []


func get_level_data(level: int) -> WeaponLevelData:
	if levels.is_empty():
		return null
	var index := clampi(level - 1, 0, levels.size() - 1)
	return levels[index]


func get_level_description(level: int) -> String:
	var level_data := get_level_data(level)
	return level_data.description if level_data else description
