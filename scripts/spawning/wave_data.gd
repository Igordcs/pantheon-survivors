extends Resource
class_name WaveData
## Dados de uma onda de inimigos.

@export var duration_seconds: float = 60.0
@export var spawn_interval: float = 1.0
@export var max_enemies: int = 50
@export_range(0.1, 100.0, 0.1) var threat_per_second: float = 1.0
@export_range(1, 30, 1) var max_batch_size: int = 4
@export var enemies: Array[EnemySpawnEntry] = []
