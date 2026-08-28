extends Node
class_name RunManager
## Gerencia o estado da partida (PLAYING, BOSS_FIGHT, VICTORY, DEFEAT).
## Invoca o Boss e coordena a transição para a tela de Results.

signal state_changed(new_state: String)
signal boss_spawned(boss_node: Node2D)
signal run_ended(is_victory: bool, stats: Dictionary)

enum State { PLAYING, BOSS_FIGHT, VICTORY, DEFEAT }

@export var spawn_director: SpawnDirector
@export var enemy_spawner: Node # Precisamos parar o spawner comum no boss?
@export var boss_scene: PackedScene = preload("res://scenes/enemies/boss_enemy.tscn")
@export var time_limit_seconds: float = 10 # 10 minutos (padrão)

var _current_state: State = State.PLAYING
var _boss_instance: Node2D


func _ready() -> void:
	if spawn_director:
		# Em vez de atrelar o fim aos 10min num timer interno,
		# podemos fazer o SpawnDirector avisar quando suas waves acabarem,
		# ou o RunManager mesmo vigia o tempo. Vamos vigiar o tempo.
		pass


func _process(delta: float) -> void:
	if _current_state != State.PLAYING:
		return
		
	if spawn_director and spawn_director._current_time >= time_limit_seconds:
		_transition_to_boss()


func _transition_to_boss() -> void:
	_current_state = State.BOSS_FIGHT
	state_changed.emit("BOSS_FIGHT")
	print("WARNING: O Deus Caído chegou!")
	
	# Desabilita spawn de inimigos comuns
	if enemy_spawner and enemy_spawner.has_method("set_process"):
		enemy_spawner.set_process(false)
		enemy_spawner.set_physics_process(false)
		# Deleta inimigos existentes? Opcional.
	
	# Spawna o boss fora da tela
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return
		
	var player = players[0]
	var spawn_pos = player.global_position + (Vector2.RIGHT.rotated(randf() * TAU) * 600)
	
	_boss_instance = boss_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(_boss_instance)
	_boss_instance.global_position = spawn_pos
	
	# Conecta morte do boss
	if _boss_instance.has_signal("died"):
		_boss_instance.died.connect(_on_boss_died)
		
	boss_spawned.emit(_boss_instance)


func _on_boss_died() -> void:
	if _current_state != State.BOSS_FIGHT:
		return
	
	# Não aciona a vitória imediatamente para o jogador poder pegar o baú.
	# A vitória será chamada pelo Game.gd após o baú ou após um timer.
	pass


func trigger_victory() -> void:
	if _current_state == State.DEFEAT or _current_state == State.VICTORY:
		return
		
	_current_state = State.VICTORY
	state_changed.emit("VICTORY")
	_show_results(true)


func trigger_defeat() -> void:
	if _current_state == State.DEFEAT or _current_state == State.VICTORY:
		return
		
	_current_state = State.DEFEAT
	state_changed.emit("DEFEAT")
	_show_results(false)


func _show_results(is_victory: bool) -> void:
	# Pausa o jogo
	get_tree().paused = true
	
	var stats = {
		"time": spawn_director._current_time if spawn_director else 0.0,
		"gold_reward": 1000 if is_victory else 100,
		"bosses_defeated": 1 if is_victory else 0
	}
	
	run_ended.emit(is_victory, stats)
