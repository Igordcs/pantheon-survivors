extends Node
class_name RunManager
## Coordinates the normal horde timeline, boss intermissions and run results.

signal state_changed(new_state: String)
signal boss_warning_started(boss_name: String, duration: float)
signal boss_spawned(boss_node: Node2D)
signal boss_fight_started(boss_pos: Vector2)
signal boss_fight_ended
signal run_ended(is_victory: bool, stats: Dictionary)

enum State { PLAYING, BOSS_WARNING, BOSS_FIGHT, BOSS_REWARD, VICTORY, DEFEAT }

@export var spawn_director: SpawnDirector
@export var enemy_spawner: EnemySpawner
@export var boss_encounters: Array[BossEncounterData] = []
@export_range(0.0, 1.0, 0.05) var horde_keep_ratio_during_boss: float = 0.45

var _current_state := State.PLAYING
var _current_encounter_index: int = 0
var _bosses_defeated: int = 0
var _boss_instance: Node2D
var boss_position := Vector2.ZERO


func _ready() -> void:
	if boss_encounters.is_empty():
		boss_encounters = _default_boss_schedule()


func _process(_delta: float) -> void:
	if _current_state == State.BOSS_FIGHT and is_instance_valid(_boss_instance):
		boss_position = _boss_instance.global_position
		return
	if _current_state != State.PLAYING or not spawn_director:
		return
	if _current_encounter_index >= boss_encounters.size():
		return
	var encounter := boss_encounters[_current_encounter_index]
	if spawn_director.get_elapsed_time() >= encounter.trigger_time:
		_begin_boss_warning(encounter)


func _begin_boss_warning(encounter: BossEncounterData) -> void:
	_current_state = State.BOSS_WARNING
	state_changed.emit("BOSS_WARNING")
	spawn_director.set_progression_paused(true)
	enemy_spawner.stop_spawning()
	enemy_spawner.reduce_active_horde(horde_keep_ratio_during_boss)
	boss_warning_started.emit(encounter.display_name, encounter.warning_duration)
	print("WARNING: %s approaches!" % encounter.display_name)
	await get_tree().create_timer(encounter.warning_duration).timeout
	if _current_state == State.BOSS_WARNING:
		_spawn_boss(encounter)


func _spawn_boss(encounter: BossEncounterData) -> void:
	var player := _find_player()
	if not player or not encounter.boss_scene:
		push_error("RunManager: could not spawn boss '%s'." % encounter.display_name)
		return
	_current_state = State.BOSS_FIGHT
	state_changed.emit("BOSS_FIGHT")
	var spawn_pos := _get_boss_spawn_position(player.global_position)
	_boss_instance = encounter.boss_scene.instantiate() as Node2D
	var container := get_tree().current_scene.get_node_or_null("World/Enemies")
	(container if container else get_tree().current_scene).add_child(_boss_instance)
	_boss_instance.global_position = spawn_pos
	boss_position = spawn_pos
	if _boss_instance.has_signal("died"):
		_boss_instance.died.connect(_on_boss_died)
	boss_spawned.emit(_boss_instance)
	boss_fight_started.emit(spawn_pos)


func _on_boss_died() -> void:
	if _current_state != State.BOSS_FIGHT:
		return
	_bosses_defeated += 1
	_current_state = State.BOSS_REWARD
	state_changed.emit("BOSS_REWARD")
	boss_fight_ended.emit()


func complete_boss_reward() -> void:
	if _current_state != State.BOSS_REWARD:
		return
	var encounter := boss_encounters[_current_encounter_index]
	if encounter.is_final_boss:
		trigger_victory()
		return
	_current_encounter_index += 1
	_current_state = State.PLAYING
	state_changed.emit("PLAYING")
	spawn_director.set_progression_paused(false)
	enemy_spawner.resume_spawning()


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


func is_boss_fight() -> bool:
	return _current_state == State.BOSS_FIGHT


func is_boss_reward_pending() -> bool:
	return _current_state == State.BOSS_REWARD


func _show_results(is_victory: bool) -> void:
	get_tree().paused = true
	var stats := {
		"time": spawn_director.get_elapsed_time() if spawn_director else 0.0,
		"gold_reward": 1000 if is_victory else 100,
		"bosses_defeated": _bosses_defeated,
	}
	run_ended.emit(is_victory, stats)


func _get_boss_spawn_position(player_position: Vector2) -> Vector2:
	var world := get_tree().current_scene.get_node_or_null("World/Environment") as WorldGenerator
	if world:
		return world.get_valid_spawn_position_around_player(player_position, 500.0, 650.0)
	return player_position + Vector2.from_angle(randf() * TAU) * 550.0


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] as CharacterBody2D if not players.is_empty() else null


func _default_boss_schedule() -> Array[BossEncounterData]:
	var result: Array[BossEncounterData] = []
	result.append(_encounter(
		&"king_slime", "King Slime", 180.0,
		preload("res://scenes/bosses/king_slime.tscn"), false
	))
	result.append(_encounter(
		&"orc_warlord", "Orc Warlord", 390.0,
		preload("res://scenes/bosses/orc_warlord.tscn"), false
	))
	result.append(_encounter(
		&"corrupted_treant", "Corrupted Treant", 600.0,
		preload("res://scenes/bosses/corrupted_treant.tscn"), true
	))
	return result


func _encounter(
	id: StringName,
	display_name: String,
	trigger_time: float,
	scene: PackedScene,
	is_final: bool
) -> BossEncounterData:
	var result := BossEncounterData.new()
	result.id = id
	result.display_name = display_name
	result.trigger_time = trigger_time
	result.boss_scene = scene
	result.warning_duration = 3.0
	result.is_final_boss = is_final
	return result
