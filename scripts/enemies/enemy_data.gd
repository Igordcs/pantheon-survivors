extends Resource
class_name EnemyData
## Dados configuráveis de um tipo de inimigo.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_health: float = 30.0
@export var speed: float = 80.0
@export var contact_damage: float = 10.0
@export var score_value: int = 10

## Tipo de inimigo: "melee", "ranged", "tank", "healer"
@export var enemy_type: StringName = &"melee"

## Ranged-only
@export var projectile_damage: float = 8.0
@export var projectile_speed: float = 300.0
@export var attack_range: float = 350.0
@export var attack_cooldown: float = 2.0

## Healer-only
@export var heal_amount: float = 10.0
@export var heal_interval: float = 3.0
@export var heal_range: float = 200.0
