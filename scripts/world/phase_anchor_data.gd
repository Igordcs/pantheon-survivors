class_name PhaseAnchorData
extends Resource
## Uma Âncora da Fenda: o chefe que sustenta a ruptura e o momento em que ele aparece.

@export var boss_id: StringName
## Quando preenchido, a run sorteia uma destas opções para esta Âncora.
## boss_id continua sendo o fallback para fases antigas e Âncoras fixas.
@export var boss_ids: Array[StringName] = []
## Segundos de run até a Âncora se manifestar.
@export_range(10.0, 3600.0, 5.0) var trigger_time: float = 180.0
@export_range(0.5, 10.0, 0.5) var warning_duration: float = 3.0


func get_boss_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for configured_id in boss_ids:
		if not configured_id.is_empty() and configured_id not in result:
			result.append(configured_id)
	if result.is_empty() and not boss_id.is_empty():
		result.append(boss_id)
	return result


func is_valid() -> bool:
	return not get_boss_ids().is_empty()
