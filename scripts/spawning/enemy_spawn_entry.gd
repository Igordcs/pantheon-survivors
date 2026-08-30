extends Resource
class_name EnemySpawnEntry
## Defines how one enemy participates in a wave, independently of its combat stats.

@export var enemy_data: EnemyData
@export var scene_key: StringName = &"melee"
@export_range(0.0, 20.0, 0.05) var weight: float = 1.0
@export_range(0.1, 20.0, 0.1) var threat_cost: float = 1.0
@export_range(1, 20, 1) var min_group_size: int = 1
@export_range(1, 20, 1) var max_group_size: int = 1
@export_range(0, 100, 1) var max_simultaneous: int = 0


func is_valid() -> bool:
	return enemy_data != null and weight > 0.0 and threat_cost > 0.0

