extends Area2D
class_name Chest
## Baú definitivo dropado ao derrotar chefes.
## Executa animação sequencial 2x2, concede ouro/evoluções e finaliza a fase.

signal collected(chest_node: Chest)
signal opened(gold_amount: int)

@export var gold_reward: int = 300
@export var is_stage_clear_chest: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var _collected: bool = false


func _ready() -> void:
	top_level = true
	sprite.frame = 0
	body_entered.connect(_on_body_entered)
	_play_spawn_animation()


func _play_spawn_animation() -> void:
	scale = Vector2.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45)


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return

	if body.is_in_group("player"):
		open_chest(body)


func open_chest(_player: Node2D) -> void:
	_collected = true
	collision.set_deferred("disabled", true)
	collected.emit(self)

	# 1. Animação sequencial nos 4 frames da textura 2x2 (0 -> 1 -> 2 -> 3)
	sprite.frame = 1
	await get_tree().create_timer(0.12).timeout
	
	sprite.frame = 2
	await get_tree().create_timer(0.15).timeout
	
	sprite.frame = 3

	# Brilho de impacto mantendo o baú aberto e estático no chão
	var shine_tween := create_tween().set_parallel(true)
	shine_tween.tween_property(sprite, "modulate", Color(1.5, 1.4, 0.8), 0.2)
	shine_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)
	shine_tween.chain().tween_property(sprite, "modulate", Color.WHITE, 0.3)
	shine_tween.tween_property(self, "scale", Vector2.ONE, 0.3)

	# 2. Recompensas em moedas
	if "coins" in Global:
		Global.coins += gold_reward
	elif "gold" in Global:
		Global.gold += gold_reward

	opened.emit(gold_reward)

	# 3. Finalização de fase (não remove o baú com queue_free)
	if is_stage_clear_chest:
		await get_tree().create_timer(1.2).timeout
		_finish_stage()


func _finish_stage() -> void:
	# 1. Para os geradores de horda e relógio
	var spawner := get_tree().get_first_node_in_group("spawner")
	if spawner and spawner.has_method("stop_spawning"):
		spawner.stop_spawning()

	var director := get_tree().get_first_node_in_group("spawn_director")
	if director and director.has_method("set_progression_paused"):
		director.set_progression_paused(true)

	# 2. Localiza o painel de resultados na interface ativa
	var results_panel = get_tree().get_first_node_in_group("results_panel")
	if not results_panel:
		results_panel = get_tree().current_scene.find_child("ResultsPanel", true, false)

	if results_panel:
		if results_panel.has_method("show_victory"):
			results_panel.show_victory()
		elif results_panel.has_method("open"):
			results_panel.open(true)
		elif results_panel is Control:
			results_panel.show()
	else:
		# Se não houver painel embutido, volta com segurança ao menu inicial
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
