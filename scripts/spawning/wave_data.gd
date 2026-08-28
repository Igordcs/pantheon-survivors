extends Resource
class_name WaveData
## Dados de uma onda de inimigos.

@export var duration_seconds: float = 60.0
@export var spawn_interval: float = 1.0
@export var max_enemies: int = 50
@export var allowed_enemies: Array[EnemyData] = []
