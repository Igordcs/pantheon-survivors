extends Area2D
class_name Chest
## Baú dropado por inimigos de Elite/Bosses.
## Ao ser coletado, verifica se o jogador atende a alguma receita de evolução.

signal collected(chest_node: Chest)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var _collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _collected: return
	
	if body.is_in_group("player"):
		_collected = true
		collected.emit(self)
		queue_free()
