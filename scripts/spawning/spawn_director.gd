extends Node
class_name SpawnDirector
## Owns the run clock and applies a controlled, data-driven horde progression per map.

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
		_setup_map_progression()
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
	print("Fase da Horda %d iniciada (Cap: %d)." % [index + 1, wave.max_enemies])


func _update_time_ui() -> void:
	var total_seconds := int(_current_time)
	time_updated.emit("%02d:%02d" % [total_seconds / 60, total_seconds % 60])


func _setup_map_progression() -> void:
	# 1. Busca o ID oficial do mapa registrado no singleton Global ou no WorldGenerator
	var current_map_id: StringName = &"field"
	
	var global_state := get_node_or_null("/root/Global")
	if global_state != null and global_state.get("selected_map_id") != null:
		current_map_id = global_state.get("selected_map_id")
	else:
		var world_gen := get_tree().get_first_node_in_group("world_generator")
		if world_gen and "active_map" in world_gen and world_gen.active_map != null:
			current_map_id = world_gen.active_map.map_id

	print("SpawnDirector — Mapa selecionado para a progressão: ", current_map_id)

	# 2. Distribui a lista de monstros de acordo com o MapCatalog (field, ruins, snow)
	match current_map_id:
		&"snow":
			print("SpawnDirector: Carregando ondas do mapa de NEVE / GELO.")
			_generate_ice_progression()
		&"ruins":
			print("SpawnDirector: Carregando ondas do mapa de RUÍNAS / TERRA DEVASTADA.")
			_generate_wasteland_progression()
		_:
			print("SpawnDirector: Carregando ondas do mapa de CAMPOS / PLANÍCIE.")
			_generate_plains_progression()

# MAPA 1: PLANÍCIE
func _generate_plains_progression() -> void:
	var bat := _entry(&"bat", 1.6, 0.5, 2, 5, 80)
	var lizard := _entry(&"lizard", 1.2, 1.2, 2, 4, 35)
	var ranged_slime := _entry(&"ranged_slime", 0.8, 1.5, 1, 3, 24)
	var healer_slime := _entry(&"healer_slime", 0.3, 2.0, 1, 2, 8)
	var cyclops := _entry(&"cyclops", 0.2, 4.0, 1, 1, 10)
	var minotaur := _entry(&"minotaur", 0.05, 8.0, 1, 1, 2)

	waves = [
		_wave(60.0, 0.8, 25, 1.2, 4, [bat]),
		_wave(60.0, 0.7, 40, 1.8, 5, [bat, lizard]),
		_wave(60.0, 0.6, 60, 2.6, 6, [bat, lizard, ranged_slime]),
		_wave(90.0, 0.55, 85, 3.8, 7, [lizard, ranged_slime, healer_slime]),
		_wave(90.0, 0.45, 120, 5.5, 8, [cyclops, ranged_slime, healer_slime]),
		_wave(120.0, 0.3, 180, 8.5, 10, [cyclops, minotaur, lizard, bat]),
	]

	horde_events = [
		_event(70.0, bat, 35, "Um bando imenso de morcegos aproxima-se!"),
		_event(160.0, ranged_slime, 16, "Slimes arcanos cercam o campo!"),
		_event(380.0, minotaur, 2, "Minotauros avançam enfurecidos!"),
	]


# MAPA 2: RUÍNAS / TERRA DEVASTADA
func _generate_wasteland_progression() -> void:
	var skeleton := _entry(&"skeleton", 1.5, 0.8, 2, 5, 60)
	var imp := _entry(&"imp", 1.2, 1.4, 2, 4, 30)
	var warlock := _entry(&"warlock", 0.6, 2.2, 1, 2, 14)
	var medusa := _entry(&"medusa", 0.4, 3.0, 1, 2, 10)
	var mummy := _entry(&"mummy", 0.4, 3.2, 1, 2, 12)
	var orc := _entry(&"orc", 0.2, 4.5, 1, 2, 10)
	var ammit := _entry(&"ammit", 0.05, 7.5, 1, 1, 3)

	waves = [
		_wave(60.0, 0.8, 30, 1.3, 4, [skeleton]),
		_wave(60.0, 0.7, 45, 2.0, 5, [skeleton, imp]),
		_wave(60.0, 0.6, 65, 2.8, 6, [skeleton, imp, warlock]),
		_wave(90.0, 0.5, 90, 4.2, 7, [imp, warlock, mummy, medusa]),
		_wave(90.0, 0.4, 130, 6.0, 9, [warlock, mummy, medusa, orc]),
		_wave(120.0, 0.28, 200, 9.5, 12, [skeleton, imp, orc, ammit, medusa]),
	]

	horde_events = [
		_event(80.0, imp, 25, "Diabretes sobrevoam a área em chamas!"),
		_event(170.0, skeleton, 40, "A horda de esqueletos ergue-se do solo!"),
		_event(390.0, ammit, 2, "Ammit surge para devorar os indignos!"),
	]


# MAPA 3: GÉLIDO
func _generate_ice_progression() -> void:
	var wolf := _entry(&"wolf", 1.6, 0.7, 3, 6, 65)
	var draugr := _entry(&"draugr", 1.3, 1.1, 2, 4, 50)
	var harpy := _entry(&"harpy", 0.8, 1.8, 1, 3, 22)
	var valkyrie := _entry(&"corrupted_valkyrie", 0.08, 6.0, 1, 2, 6)

	waves = [
		_wave(60.0, 0.75, 30, 1.4, 5, [wolf]),
		_wave(60.0, 0.65, 50, 2.2, 6, [wolf]),
		_wave(60.0, 0.55, 75, 3.2, 7, [wolf, draugr]),
		_wave(90.0, 0.45, 105, 4.8, 8, [draugr, harpy, wolf]),
		_wave(90.0, 0.35, 145, 7.0, 10, [draugr, harpy, valkyrie]),
		_wave(120.0, 0.25, 220, 10.5, 13, [wolf, draugr, harpy, valkyrie]),
	]

	horde_events = [
		_event(75.0, wolf, 30, "Uma matilha implacável de lobos ataca!"),
		_event(180.0, draugr, 35, "Guerreiros Draugr emergem da nevasca!"),
		_event(420.0, valkyrie, 3, "Valquírias Corrompidas descem dos céus!"),
	]


func _entry(
	enemy_id: StringName,
	weight: float,
	cost: float,
	min_group: int,
	max_group: int,
	max_simultaneous: int
) -> EnemySpawnEntry:
	var result := EnemySpawnEntry.new()
	result.enemy_data = ContentRegistry.get_enemy_data(enemy_id)
	result.scene_key = enemy_id
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