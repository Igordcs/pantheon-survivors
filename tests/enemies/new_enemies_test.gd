extends Node

var _failures := 0


func _ready() -> void:
	_test_combat_data()
	_test_scenes_and_assets()
	_test_progression()
	_test_final_boss_pool()
	if _failures == 0:
		print("New enemy and Fenrir tests passed.")
	get_tree().quit(_failures)


func _test_combat_data() -> void:
	var slime := load("res://resources/enemies/ranged_enemy_data.tres") as EnemyData
	var ammit := load("res://resources/enemies/ammit_data.tres") as EnemyData
	var valkyrie := load("res://resources/enemies/corrupted_valkyrie_data.tres") as EnemyData
	var fenrir := load("res://resources/bosses/fenrir_data.tres") as EnemyData
	if slime.projectile_speed != 220.0:
		_fail("Arcane Slime projectile speed should be 220.")
	if ammit.max_health != 480.0 or valkyrie.max_health != 360.0:
		_fail("Late-run enemy health does not match the balance specification.")
	if fenrir.max_health != 10500.0:
		_fail("Fenrir should have 10,500 health.")


func _test_scenes_and_assets() -> void:
	for path in [
		"res://scenes/enemies/ammit.tscn",
		"res://scenes/enemies/corrupted_valkyrie.tscn",
		"res://scenes/bosses/fenrir.tscn",
	]:
		if not ResourceLoader.exists(path) or not (load(path) is PackedScene):
			_fail("Missing scene: %s" % path)
	for directory in [
		"res://assets/sprites/enemies/ammit/Idle/rotations",
		"res://assets/sprites/enemies/corrupted_valkyrie/Idle/rotations",
		"res://assets/sprites/bosses/fenrir/Idle/rotations",
	]:
		for direction in ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]:
			if not ResourceLoader.exists("%s/%s.png" % [directory, direction]):
				_fail("Missing directional sprite: %s/%s.png" % [directory, direction])


func _test_progression() -> void:
	var director := SpawnDirector.new()
	director.call("_generate_default_progression")
	var ammit_first_wave := -1
	var valkyrie_first_wave := -1
	for wave_index in director.waves.size():
		for entry in director.waves[wave_index].enemies:
			if entry.enemy_data.id == &"ammit" and ammit_first_wave < 0:
				ammit_first_wave = wave_index
				if entry.max_simultaneous != 6:
					_fail("Ammit simultaneous cap should be six.")
			if entry.enemy_data.id == &"corrupted_valkyrie" and valkyrie_first_wave < 0:
				valkyrie_first_wave = wave_index
				if entry.max_simultaneous != 8:
					_fail("Corrupted Valkyrie simultaneous cap should be eight.")
	if ammit_first_wave != 4 or valkyrie_first_wave != 5:
		_fail("Ammit and Corrupted Valkyrie should debut at 05:00 and 06:30.")
	director.free()


func _test_final_boss_pool() -> void:
	var manager := RunManager.new()
	var schedule: Array = manager.call("_default_boss_schedule")
	var final_ids: Array[StringName] = []
	for candidate in schedule.back().candidates:
		final_ids.append(candidate.id)
	if final_ids != [&"corrupted_treant", &"jormungandr", &"fenrir"]:
		_fail("Final boss pool should contain Treant, Jormungandr and Fenrir.")
	manager.free()


func _fail(message: String) -> void:
	_failures += 1
	push_error("New enemies test: %s" % message)
