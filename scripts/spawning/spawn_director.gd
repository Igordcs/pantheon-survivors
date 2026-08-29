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
	var basic_enemy = load("res://resources/enemies/basic_enemy_data.tres")
	var runner_enemy = load("res://resources/enemies/runner_data.tres")
	var tank_enemy = load("res://resources/enemies/tank_data.tres")
	var ranged_enemy = load("res://resources/enemies/ranged_enemy_data.tres")
	var healer_enemy = load("res://resources/enemies/healer_enemy_data.tres")
	
	waves.clear()
	
	# Curva de 10 minutos (600 segundos) dividida em 5 waves
	
	# Wave 1: 0-2min (Basic)
	var wave1 = WaveData.new()
	wave1.duration_seconds = 120.0
	wave1.spawn_interval = 1.0
	wave1.max_enemies = 30
	if basic_enemy: wave1.allowed_enemies.append(basic_enemy)
	waves.append(wave1)
	
	# Wave 2: 2-4min (Basic + Runner)
	var wave2 = WaveData.new()
	wave2.duration_seconds = 120.0
	wave2.spawn_interval = 0.8
	wave2.max_enemies = 50
	if basic_enemy: wave2.allowed_enemies.append(basic_enemy)
	if runner_enemy: wave2.allowed_enemies.append(runner_enemy)
	waves.append(wave2)
	
	# Wave 3: 4-6min (Runner + Tank + Ranged)
	var wave3 = WaveData.new()
	wave3.duration_seconds = 120.0
	wave3.spawn_interval = 0.6
	wave3.max_enemies = 80
	if runner_enemy: wave3.allowed_enemies.append(runner_enemy)
	if tank_enemy: wave3.allowed_enemies.append(tank_enemy)
	if ranged_enemy: wave3.allowed_enemies.append(ranged_enemy)
	waves.append(wave3)
	
	# Wave 4: 6-8min (All enemies + Healer)
	var wave4 = WaveData.new()
	wave4.duration_seconds = 120.0
	wave4.spawn_interval = 0.4
	wave4.max_enemies = 150
	if basic_enemy: wave4.allowed_enemies.append(basic_enemy)
	if runner_enemy: wave4.allowed_enemies.append(runner_enemy)
	if tank_enemy: wave4.allowed_enemies.append(tank_enemy)
	if ranged_enemy: wave4.allowed_enemies.append(ranged_enemy)
	if healer_enemy: wave4.allowed_enemies.append(healer_enemy)
	waves.append(wave4)
	
	# Wave 5: 8-10min (Massive spawn before boss)
	var wave5 = WaveData.new()
	wave5.duration_seconds = 120.0
	wave5.spawn_interval = 0.2
	wave5.max_enemies = 300
	if basic_enemy: wave5.allowed_enemies.append(basic_enemy)
	if runner_enemy: wave5.allowed_enemies.append(runner_enemy)
	if tank_enemy: wave5.allowed_enemies.append(tank_enemy)
	if ranged_enemy: wave5.allowed_enemies.append(ranged_enemy)
	if healer_enemy: wave5.allowed_enemies.append(healer_enemy)
	waves.append(wave5)


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
