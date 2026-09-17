extends EnemyData
class_name BossData
## Dados exclusivos de bosses; mantém compatibilidade com consumidores de EnemyData.

@export var phase_health_thresholds: Array[float] = []
@export var reward_chest_count: int = 1
@export var music_id: StringName = &"boss"
@export var is_final_candidate: bool = false
## Título curto exibido acima do nome quando a Âncora se manifesta.
@export var epithet: String = ""
## Por que esta criatura sustenta a ruptura (docs/lore.md).
@export_multiline var presentation_text: String = ""
