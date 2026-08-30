extends Node
class_name RunManager
## Gerencia o estado da partida (PLAYING, BOSS_FIGHT, VICTORY, DEFEAT).
## Invoca o Boss e coordena a transição para a tela de Results.

signal state_changed(new_state: String)
signal boss_spawned(boss_node: Node2D)
signal run_ended(is_victory: bool, stats: Dictionary)
signal boss_fight_started(boss_pos: Vector2)
signal boss_fight_ended

enum State { PLAYING, BOSS_FIGHT, VICTORY, DEFEAT }

@export var spawn_director: SpawnDirector
@export var enemy_spawner: Node
@export var boss_scene: PackedScene = preload("res://scenes/enemies/boss_enemy.tscn")
@export var time_limit_seconds: float = 10

var _current_state: State = State.PLAYING
var _bosses_spawned: int = 0
var _boss_instance: Node2D
var boss_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if spawn_director:
		pass


func _process(delta: float) -> void:
	if _current_state != State.PLAYING:
		return
		
	if spawn_director and spawn_director._current_time >= time_limit_seconds:
		_transition_to_boss()
	
	# Atualiza a posição do boss para o boundary do player
	if _current_state == State.BOSS_FIGHT and is_instance_valid(_boss_instance):
		boss_position = _boss_instance.global_position


func _transition_to_boss() -> void:
	_current_state = State.BOSS_FIGHT
	state_changed.emit("BOSS_FIGHT")
	_bosses_spawned += 1;
	print("WARNING: O Deus Caído chegou!")
	
	# Desabilita spawn de inimigos comuns
	if enemy_spawner and enemy_spawner.has_method("stop_spawning"):
		enemy_spawner.stop_spawning()
	
	# Spawna o boss próximo do player (300px) mas não em cima
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
		
	var player = players[0]
	var spawn_dir = Vector2.RIGHT.rotated(randf() * TAU)
	var spawn_pos = player.global_position + spawn_dir * 250.0
	
	_boss_instance = boss_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(_boss_instance)
	_boss_instance.global_position = spawn_pos
	boss_position = spawn_pos
	
	# Conecta morte do boss
	if _boss_instance.has_signal("died"):
		_boss_instance.died.connect(_on_boss_died)
		
	boss_spawned.emit(_boss_instance)
	boss_fight_started.emit(spawn_pos)


func _on_boss_died() -> void:
	if _current_state != State.BOSS_FIGHT:
		return
	boss_fight_ended.emit()


func trigger_victory() -> void:
	if _current_state == State.DEFEAT or _current_state == State.VICTORY:
		return
		
	_current_state = State.VICTORY
	state_changed.emit("VICTORY")
	boss_fight_ended.emit()
	_show_results(true)


func trigger_defeat() -> void:
	if _current_state == State.DEFEAT or _current_state == State.VICTORY:
		return
		
	_current_state = State.DEFEAT
	state_changed.emit("DEFEAT")
	boss_fight_ended.emit()
	_show_results(false)


func _show_results(is_victory: bool) -> void:
	get_tree().paused = true
	
	var stats = {
		"time": spawn_director._current_time if spawn_director else 0.0,
		"gold_reward": 1000 if is_victory else 100,
		"bosses_defeated": _bosses_spawned if is_victory else 0
	}
	
	run_ended.emit(is_victory, stats)


func is_boss_fight() -> bool:
	return _current_state == State.BOSS_FIGHT
