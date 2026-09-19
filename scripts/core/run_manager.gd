extends Node
class_name RunManager
## Coordinates the normal horde timeline, boss intermissions and run results.

signal state_changed(new_state: String)
signal boss_warning_started(boss_name: String, duration: float)
## Emitido junto do aviso, com a lore da Âncora que está chegando.
signal boss_introduced(boss_id: StringName, display_name: String, duration: float)
## Frase de abertura da fase, no primeiro instante da run.
signal phase_started(intro_line: String)
## Emitido quando uma Âncora cai e a ruptura ainda resiste.
signal anchor_sealed(remaining: int)
signal boss_spawned(boss_node: Node2D)
signal boss_fight_started(boss_pos: Vector2)
signal boss_fight_ended
signal run_ended(is_victory: bool, stats: Dictionary)
## Quantas Âncoras da fase já caíram, e quantas a ruptura tem no total.
signal anchor_progress_changed(defeated: int, total: int)

enum State { PLAYING, BOSS_WARNING, BOSS_FIGHT, BOSS_REWARD, VICTORY, DEFEAT }

@export var spawn_director: SpawnDirector
@export var enemy_spawner: EnemySpawner
@export var boss_encounters: Array[BossEncounterData] = []
@export_range(0.0, 1.0, 0.05) var horde_keep_ratio_during_boss: float = 0.45
@export var boss_selection_seed: int = 0

var _current_state := State.PLAYING
var _current_encounter_index: int = 0
var _bosses_defeated: int = 0
var _boss_instance: Node2D
var boss_position := Vector2.ZERO
var _boss_rng := RandomNumberGenerator.new()
var active_phase: PhaseData


func _ready() -> void:
	active_phase = _resolve_phase()
	if boss_encounters.is_empty() and active_phase != null:
		boss_encounters = _encounters_from_phase(active_phase)
	if boss_encounters.is_empty():
		boss_encounters = _default_boss_schedule()
	_configure_boss_rng()
	_resolve_boss_candidates()
	_emit_anchor_progress.call_deferred()
	_announce_phase.call_deferred()


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
	var keep_ratio := 0.0 if encounter.is_final_boss else horde_keep_ratio_during_boss
	enemy_spawner.reduce_active_horde(keep_ratio)
	boss_warning_started.emit(encounter.display_name, encounter.warning_duration)
	boss_introduced.emit(encounter.id, encounter.display_name, encounter.warning_duration)
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
	_configure_horde_for_boss(encounter)
	boss_spawned.emit(_boss_instance)
	boss_fight_started.emit(spawn_pos)


func _configure_horde_for_boss(encounter: BossEncounterData) -> void:
	if encounter.is_final_boss:
		enemy_spawner.stop_spawning()
	else:
		enemy_spawner.resume_spawning()


func _on_boss_died() -> void:
	if _current_state != State.BOSS_FIGHT:
		return
	_bosses_defeated += 1
	_emit_anchor_progress()
	anchor_sealed.emit(get_remaining_anchors())
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
	_seal_active_phase()
	_show_results(true)


## Derrubar a ultima Ancora fecha a ruptura. O modo sandbox nao altera progresso.
func _seal_active_phase() -> void:
	if active_phase == null:
		return
	var global_state := get_node_or_null("/root/Global")
	if global_state != null and bool(global_state.get("sandbox_mode")):
		return
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return
	save_manager.complete_phase(active_phase.phase_id)


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
	var next_phase := PhaseCatalog.get_next_phase(active_phase.phase_id) if active_phase else null
	var stats := {
		"time": spawn_director.get_elapsed_time() if spawn_director else 0.0,
		"coins_collected": 0,
		"bosses_defeated": _bosses_defeated,
		"phase_id": active_phase.phase_id if active_phase else &"",
		"phase_name": active_phase.display_name if active_phase else "",
		"anchor_count": active_phase.get_anchor_count() if active_phase else 0,
		"next_phase_name": next_phase.display_name if next_phase else "",
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
		180.0,
		[_candidate(
			&"king_slime", "King Slime"
		)],
		false
	))
	result.append(_encounter(
		390.0,
		[
			_candidate(
				&"orc_warlord", "Orc Warlord"
			),
			_candidate(
				&"cerberus", "Cerberus"
			),
		],
		false
	))
	result.append(_encounter(
		600.0,
		[
			_candidate(
				&"corrupted_treant", "Corrupted Treant"
			),
			_candidate(
				&"jormungandr", "Jormungandr"
			),
			_candidate(
				&"fenrir", "Fenrir"
			),
		],
		true
	))
	return result


## Prioridade: a fase escolhida na sessao, senao a primeira da campanha.
func _resolve_phase() -> PhaseData:
	var global_state := get_node_or_null("/root/Global")
	if global_state != null:
		var selected: StringName = global_state.get("selected_phase_id")
		if not String(selected).is_empty():
			return PhaseCatalog.get_phase(selected)
	return PhaseCatalog.get_first_phase()


func _encounters_from_phase(phase: PhaseData) -> Array[BossEncounterData]:
	var result: Array[BossEncounterData] = []
	var anchors := phase.get_anchors()
	for index in range(anchors.size()):
		var anchor := anchors[index]
		var candidates: Array[BossCandidateData] = []
		for boss_id in anchor.get_boss_ids():
			var candidate := _candidate(boss_id, ContentRegistry.get_boss_display_name(boss_id))
			if candidate.boss_scene == null:
				push_warning("RunManager: Âncora \"%s\" não tem cena." % boss_id)
				continue
			candidates.append(candidate)
		if candidates.is_empty():
			continue
		var encounter := BossEncounterData.new()
		encounter.candidates = candidates
		encounter.trigger_time = anchor.trigger_time
		encounter.warning_duration = anchor.warning_duration
		encounter.is_final_boss = index == anchors.size() - 1
		result.append(encounter)
	return result


func _announce_phase() -> void:
	if active_phase != null and not active_phase.intro_line.is_empty():
		phase_started.emit(active_phase.intro_line)


func _emit_anchor_progress() -> void:
	anchor_progress_changed.emit(_bosses_defeated, boss_encounters.size())


func get_anchor_total() -> int:
	return boss_encounters.size()


func get_remaining_anchors() -> int:
	return maxi(boss_encounters.size() - _bosses_defeated, 0)


func _encounter(
	trigger_time: float,
	candidates: Array[BossCandidateData],
	is_final: bool
) -> BossEncounterData:
	var result := BossEncounterData.new()
	result.trigger_time = trigger_time
	result.candidates = candidates
	result.warning_duration = 3.0
	result.is_final_boss = is_final
	return result


func _candidate(
	id: StringName,
	display_name: String,
	weight: float = 1.0
) -> BossCandidateData:
	var result := BossCandidateData.new()
	result.id = id
	result.display_name = display_name
	result.boss_scene = ContentRegistry.get_boss_scene(id)
	result.selection_weight = weight
	return result


func _configure_boss_rng() -> void:
	if boss_selection_seed == 0:
		_boss_rng.randomize()
		boss_selection_seed = int(_boss_rng.seed)
	else:
		_boss_rng.seed = boss_selection_seed
	print("RunManager: boss selection seed = %d" % boss_selection_seed)


func _resolve_boss_candidates() -> void:
	for encounter in boss_encounters:
		if encounter.candidates.is_empty():
			continue
		var selected := _pick_weighted_candidate(encounter.candidates)
		if selected == null:
			push_error("RunManager: boss encounter at %.1f has no valid candidate." % encounter.trigger_time)
			continue
		encounter.id = selected.id
		encounter.display_name = selected.display_name
		encounter.boss_scene = selected.boss_scene
		print("RunManager: selected %s for %.1f seconds." % [selected.display_name, encounter.trigger_time])


func _pick_weighted_candidate(candidates: Array[BossCandidateData]) -> BossCandidateData:
	var total_weight := 0.0
	for candidate in candidates:
		if candidate and candidate.boss_scene:
			total_weight += maxf(candidate.selection_weight, 0.0)
	if total_weight <= 0.0:
		return null

	var roll := _boss_rng.randf_range(0.0, total_weight)
	for candidate in candidates:
		if not candidate or not candidate.boss_scene:
			continue
		roll -= maxf(candidate.selection_weight, 0.0)
		if roll <= 0.0:
			return candidate
	return candidates.back()
