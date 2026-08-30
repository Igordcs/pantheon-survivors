extends Resource
class_name HordeEventData
## A deterministic pressure spike within the normal wave timeline.

@export var trigger_time: float = 60.0
@export var entry: EnemySpawnEntry
@export_range(1, 40, 1) var group_size: int = 1
@export var announcement: String = ""

