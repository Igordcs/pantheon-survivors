extends Resource
class_name BossCandidateData
## A weighted boss option available for one scheduled encounter.

@export var id: StringName
@export var display_name: String
@export var boss_scene: PackedScene
@export_range(0.0, 100.0, 0.1) var selection_weight: float = 1.0
