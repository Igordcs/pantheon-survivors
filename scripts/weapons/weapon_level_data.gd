extends Resource
class_name WeaponLevelData
## Estado completo de uma arma em um nível específico.

@export_multiline var description: String = ""
@export_range(0.0, 10.0, 0.05) var damage_multiplier: float = 1.0
@export_range(0.05, 10.0, 0.05) var cooldown_multiplier: float = 1.0
@export_range(0.05, 10.0, 0.05) var area_multiplier: float = 1.0
@export_range(0.05, 10.0, 0.05) var speed_multiplier: float = 1.0
@export_range(1, 16, 1) var projectile_count: int = 1
@export var special_effect: StringName = &""
@export var special_value: float = 0.0
