class_name PhaseAnchorData
extends Resource
## Uma Âncora da Fenda: o chefe que sustenta a ruptura e o momento em que ele aparece.

@export var boss_id: StringName
## Segundos de run até a Âncora se manifestar.
@export_range(10.0, 3600.0, 5.0) var trigger_time: float = 180.0
@export_range(0.5, 10.0, 0.5) var warning_duration: float = 3.0
