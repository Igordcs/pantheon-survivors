extends Node
## Global — Mantém o estado da sessão (entre cenas).

var selected_character_id: StringName = &"eirik"
## Fase escolhida para a run. Ela é quem define o mapa em jogo normal.
var selected_phase_id: StringName = &"phase_1"
## Resolvido a partir da fase; o modo dev pode sobrescrever para testar um mapa solto.
var selected_map_id: StringName = &"field"
var sandbox_mode: bool = false
