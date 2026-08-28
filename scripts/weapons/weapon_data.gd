extends Resource
class_name WeaponData
## Dados configuráveis de uma arma.

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_damage: float = 15.0
@export var cooldown: float = 1.2
@export var area: float = 250.0
@export var projectile_speed: float = 600.0
@export var projectile_count: int = 1
@export var max_level: int = 8
