extends Node
class_name SpawnDirector
## Owns the run clock and applies a controlled, data-driven horde progression.

signal time_updated(time_string: String)
signal wave_started(index: int, wave: WaveData)
signal horde_event_started(message: String)

@export var waves: Array[WaveData] = []
@export var horde_events: Array[HordeEventData] = []
@export var spawner: EnemySpawner

var _current_time: float = 0.0
var _current_wave_index: int = 0
var _wave_timer: float = 0.0
var _next_event_index: int = 0
var _progression_paused: bool = false


func _ready() -> void:
	if waves.is_empty():
		_generate_default_progression()
	if not waves.is_empty():
		_apply_wave(0)


func _process(delta: float) -> void:
	if _progression_paused or waves.is_empty():
		return
	_current_time += delta
	_wave_timer += delta
	_update_time_ui()
	_process_horde_events()

	var current_wave := waves[_current_wave_index]
	while _wave_timer >= current_wave.duration_seconds and _current_wave_index < waves.size() - 1:
		_wave_timer -= current_wave.duration_seconds
		_current_wave_index += 1
		_apply_wave(_current_wave_index)
		current_wave = waves[_current_wave_index]


func set_progression_paused(paused: bool) -> void:
	_progression_paused = paused


func get_elapsed_time() -> float:
	return _current_time


func _process_horde_events() -> void:
	while _next_event_index < horde_events.size():
		var event := horde_events[_next_event_index]
		if event.trigger_time > _current_time:
			break
		_next_event_index += 1
		if event.entry and is_instance_valid(spawner):
			spawner.spawn_event(event.entry, event.group_size)
			horde_event_started.emit(event.announcement)


func _apply_wave(index: int) -> void:
	var wave := waves[index]
	if is_instance_valid(spawner):
		spawner.apply_wave_data(wave)
	wave_started.emit(index, wave)
	print("Horde phase %d started (cap: %d)." % [index + 1, wave.max_enemies])


func _update_time_ui() -> void:
	var total_seconds := int(_current_time)
	time_updated.emit("%02d:%02d" % [total_seconds / 60, total_seconds % 60])


func _generate_default_progression() -> void:
	var bat := _entry("res://resources/enemies/bat_data.tres", &"bat", 1.6, 0.5, 2, 5, 30)
	var draugr := _entry("res://resources/enemies/draugr_data.tres", &"melee", 1.4, 1.0, 1, 3, 0)
	var harpy := _entry("res://resources/enemies/harpy_data.tres", &"melee", 0.8, 1.25, 1, 3, 18)
	var ranged_slime := _entry("res://resources/enemies/ranged_enemy_data.tres", &"ranged", 0.7, 1.5, 1, 2, 12)
	var healer_slime := _entry("res://resources/enemies/healer_enemy_data.tres", &"healer", 0.25, 2.5, 1, 1, 6)
	var medusa := _entry("res://resources/enemies/medusa_data.tres", &"directional_ranged", 0.35, 3.0, 1, 2, 8)
	var mummy := _entry("res://resources/enemies/mummy_data.tres", &"directional_ranged", 0.3, 3.0, 1, 2, 10)
	var cyclops := _entry("res://resources/enemies/cyclops_data.tres", &"melee", 0.15, 4.0, 1, 1, 10)
	var orc := _entry("res://resources/enemies/tank_data.tres", &"tank", 0.12, 5.0, 1, 1, 8)
	var minotaur := _entry("res://resources/enemies/minotaur_data.tres", &"charger", 0.04, 8.0, 1, 1, 1)

	waves = [
		_wave(60.0, 0.8, 25, 1.2, 4, [bat, draugr]),
		_wave(60.0, 0.7, 40, 1.8, 5, [bat, draugr, harpy]),
		_wave(60.0, 0.6, 55, 2.6, 6, [bat, draugr, harpy, ranged_slime]),
		_wave(120.0, 0.55, 80, 3.8, 7, [draugr, harpy, ranged_slime, healer_slime, medusa]),
		_wave(90.0, 0.45, 110, 5.2, 8, [draugr, harpy, ranged_slime, healer_slime, medusa, mummy, cyclops]),
		_wave(90.0, 0.35, 150, 7.0, 10, [harpy, ranged_slime, healer_slime, medusa, mummy, cyclops, orc]),
		_wave(120.0, 0.25, 220, 10.0, 12, [bat, draugr, harpy, ranged_slime, healer_slime, medusa, mummy, cyclops, orc, minotaur]),
	]

	horde_events = [
		_event(90.0, bat, 12, "A swarm of bats approaches!"),
		_event(150.0, ranged_slime, 6, "Ranged slimes surround the battlefield!"),
		_event(450.0, minotaur, 1, "A Minotaur has entered the horde!"),
		_event(540.0, bat, 20, "The final horde is gathering!"),
	]


func _entry(
	data_path: String,
	scene_key: StringName,
	weight: float,
	cost: float,
	min_group: int,
	max_group: int,
	max_simultaneous: int
) -> EnemySpawnEntry:
	var result := EnemySpawnEntry.new()
	result.enemy_data = load(data_path) as EnemyData
	result.scene_key = scene_key
	result.weight = weight
	result.threat_cost = cost
	result.min_group_size = min_group
	result.max_group_size = max_group
	result.max_simultaneous = max_simultaneous
	return result


func _wave(
	duration: float,
	interval: float,
	cap: int,
	threat: float,
	batch: int,
	entries: Array
) -> WaveData:
	var result := WaveData.new()
	result.duration_seconds = duration
	result.spawn_interval = interval
	result.max_enemies = cap
	result.threat_per_second = threat
	result.max_batch_size = batch
	for entry in entries:
		result.enemies.append(entry as EnemySpawnEntry)
	return result


func _event(time: float, entry: EnemySpawnEntry, count: int, message: String) -> HordeEventData:
	var result := HordeEventData.new()
	result.trigger_time = time
	result.entry = entry
	result.group_size = count
	result.announcement = message
	return result
