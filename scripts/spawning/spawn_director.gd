extends Node
class_name SpawnDirector
## Controla o tempo de jogo e dita o ritmo de spawn para o EnemySpawner.

signal time_updated(time_string: String)

@export var waves: Array[WaveData] = []
@export var spawner: Node # Referência ao EnemySpawner

var _current_time: float = 0.0
var _current_wave_index: int = 0
var _wave_timer: float = 0.0


func _ready() -> void:
	if waves.is_empty():
		_generate_default_waves()
		
	if waves.is_empty():
		return
	_apply_wave(0)


func _generate_default_waves() -> void:
	var enemy_roster: Array[EnemyData] = [
		load("res://resources/enemies/medusa_data.tres") as EnemyData,
		load("res://resources/enemies/draugr_data.tres") as EnemyData,
		load("res://resources/enemies/cyclops_data.tres") as EnemyData,
		load("res://resources/enemies/mummy_data.tres") as EnemyData,
		load("res://resources/enemies/minotaur_data.tres") as EnemyData,
		load("res://resources/enemies/harpy_data.tres") as EnemyData,
	]
	
	waves.clear()
	
	# Curva de 10 minutos (600 segundos) dividida em 5 waves
	
	# Wave 1: 0-2min
	var wave1 = WaveData.new()
	wave1.duration_seconds = 120.0
	wave1.spawn_interval = 1.0
	wave1.max_enemies = 30
	_append_available_enemies(wave1, enemy_roster)
	waves.append(wave1)
	
	# Wave 2: 2-4min
	var wave2 = WaveData.new()
	wave2.duration_seconds = 120.0
	wave2.spawn_interval = 0.8
	wave2.max_enemies = 50
	_append_available_enemies(wave2, enemy_roster)
	waves.append(wave2)
	
	# Wave 3: 4-6min
	var wave3 = WaveData.new()
	wave3.duration_seconds = 120.0
	wave3.spawn_interval = 0.6
	wave3.max_enemies = 80
	_append_available_enemies(wave3, enemy_roster)
	waves.append(wave3)
	
	# Wave 4: 6-8min
	var wave4 = WaveData.new()
	wave4.duration_seconds = 120.0
	wave4.spawn_interval = 0.4
	wave4.max_enemies = 150
	_append_available_enemies(wave4, enemy_roster)
	waves.append(wave4)
	
	# Wave 5: 8-10min (Massive spawn before boss)
	var wave5 = WaveData.new()
	wave5.duration_seconds = 120.0
	wave5.spawn_interval = 0.2
	wave5.max_enemies = 300
	_append_available_enemies(wave5, enemy_roster)
	waves.append(wave5)


func _append_available_enemies(wave: WaveData, enemy_roster: Array[EnemyData]) -> void:
	for enemy_data in enemy_roster:
		if enemy_data and enemy_data.has_visual():
			wave.allowed_enemies.append(enemy_data)


func _process(delta: float) -> void:
	if waves.is_empty():
		return
		
	_current_time += delta
	_update_time_ui()
	
	_wave_timer += delta
	var current_wave = waves[_current_wave_index]
	
	if _wave_timer >= current_wave.duration_seconds:
		_wave_timer -= current_wave.duration_seconds
		_next_wave()


func _next_wave() -> void:
	if _current_wave_index < waves.size() - 1:
		_current_wave_index += 1
		_apply_wave(_current_wave_index)
	# Se for a última wave, fica nela indefinidamente (ou ganha o jogo futuramente)


func _apply_wave(index: int) -> void:
	var wave = waves[index]
	if is_instance_valid(spawner) and spawner.has_method("apply_wave_data"):
		spawner.apply_wave_data(wave)
	print("Wave ", index + 1, " iniciada!")


func _update_time_ui() -> void:
	var total_seconds := int(_current_time)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	var time_str := "%02d:%02d" % [minutes, seconds]
	time_updated.emit(time_str)
