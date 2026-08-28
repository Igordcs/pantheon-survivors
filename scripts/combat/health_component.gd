extends Node
class_name HealthComponent
## Componente de saúde reutilizável para Player e Enemies.

signal health_changed(current_health: float, max_health: float)
signal died
signal damaged(amount: float, source_pos: Vector2)

@export var max_health: float = 100.0

var current_health: float


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float, source_pos: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, source_pos)
	
	if DamageNumbers and get_parent() is Node2D:
		DamageNumbers.show_number(amount, get_parent().global_position)
		
	if current_health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func is_alive() -> bool:
	return current_health > 0.0


func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
