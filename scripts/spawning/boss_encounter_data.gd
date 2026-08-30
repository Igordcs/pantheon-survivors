extends Resource
class_name BossEncounterData
## Timeline and presentation data for a boss encounter.

@export var id: StringName
@export var display_name: String
@export var trigger_time: float = 180.0
@export var boss_scene: PackedScene
@export var candidates: Array[BossCandidateData] = []
@export var warning_duration: float = 3.0
@export var is_final_boss: bool = false
