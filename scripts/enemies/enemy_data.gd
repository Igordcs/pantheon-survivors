extends Resource
class_name EnemyData
## Dados configuráveis de um tipo de inimigo.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_health: float = 30.0
@export var speed: float = 80.0
@export var contact_damage: float = 10.0
@export var score_value: int = 10
