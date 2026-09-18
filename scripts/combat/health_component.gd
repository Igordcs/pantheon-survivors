extends Node
class_name HealthComponent
## Componente de saúde reutilizável para Player e Enemies.

signal health_changed(current_health: float, max_health: float)
signal died
signal damaged(amount: float, source_pos: Vector2)

@export var max_health: float = 100.0
## Redução flat de dano recebido (subtraída antes de qualquer outro processamento).
## Usada pela passiva de Arthur ("Determinação do Rei").
var flat_damage_reduction: float = 0.0

var current_health: float


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float, source_pos: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0.0:
		return
	if flat_damage_reduction > 0.0:
		amount = maxf(0.0, amount - flat_damage_reduction)
	if amount <= 0.0:
		return
	var item_controller := get_parent().get_node_or_null("ItemEffectController") as ItemEffectController
	if item_controller:
		amount = item_controller.absorb_damage(amount)
	elif get_parent().is_in_group("enemies"):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var attacker_items := players[0].get_node_or_null("ItemEffectController") as ItemEffectController
			if attacker_items: amount *= attacker_items.get_damage_multiplier()
		if int(get_parent().get_meta("odin_marked_until", 0)) > Time.get_ticks_msec(): amount *= 1.25
	if amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, source_pos)
	
	if DamageNumbers and get_parent() is Node2D:
		DamageNumbers.show_number(amount, get_parent().global_position)
		
	if current_health <= 0.0 and item_controller and item_controller.try_revive():
		return
	if current_health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
	var overheal := maxf(current_health + amount - max_health, 0.0)
	current_health = minf(current_health + amount, max_health)
	var item_controller := get_parent().get_node_or_null("ItemEffectController") as ItemEffectController
	if item_controller and overheal > 0.0: item_controller.add_overheal(overheal)
	health_changed.emit(current_health, max_health)


func is_alive() -> bool:
	return current_health > 0.0


func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
