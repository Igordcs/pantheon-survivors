class_name PhaseData
extends Resource
## Uma fase da campanha: uma ruptura no Véu, o mapa onde ela abriu e as Âncoras
## que precisam cair para selá-la (docs/lore.md).

@export var phase_id: StringName = &"phase_1"
@export var display_name: String = "Campos da Ruptura"
@export_multiline var description: String = ""
## Frase curta exibida ao iniciar a fase.
@export var intro_line: String = ""
## Posição na campanha, a partir de 1. Define a ordem de desbloqueio.
@export var order: int = 1
## Mapa usado por esta fase, resolvido pelo MapCatalog.
@export var map_id: StringName = &"field"
## Âncoras em ordem cronológica. A última encerra a fase.
@export var anchors: Array[PhaseAnchorData] = []
## Cor de destaque do card na seleção de fases.
@export var accent_color: Color = Color(1.0, 0.82, 0.3)


func get_anchors() -> Array[PhaseAnchorData]:
	var result: Array[PhaseAnchorData] = []
	for anchor in anchors:
		if anchor != null and anchor.is_valid():
			result.append(anchor)
	return result


func get_anchor_count() -> int:
	return get_anchors().size()


func get_duration() -> float:
	var result := 0.0
	for anchor in get_anchors():
		result = maxf(result, anchor.trigger_time)
	return result


func is_valid() -> bool:
	return not phase_id.is_empty() and not map_id.is_empty() and not get_anchors().is_empty()
