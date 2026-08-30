extends Node

var _failures := 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	var player_health := HealthComponent.new()
	player.add_child(player_health)
	add_child(player)

	var spawner := EnemySpawner.new()
	spawner.enemy_scene = load("res://scenes/enemies/basic_enemy.tscn") as PackedScene
	add_child(spawner)
	var director := SpawnDirector.new()
	director.spawner = spawner
	add_child(director)
	await get_tree().process_frame
	spawner.stop_spawning()

	if director.waves.size() != 7:
		_fail("The default progression should contain seven horde phases.")
	var total_duration := 0.0
	for wave in director.waves:
		total_duration += wave.duration_seconds
	if not is_equal_approx(total_duration, 600.0):
		_fail("The horde phases should cover exactly ten gameplay minutes.")
	if _entry_ids(director.waves[0]) != [&"bat", &"draugr"]:
		_fail("The opening phase should only contain bats and Draugr.")

	var final_ids := _entry_ids(director.waves.back())
	for expected_id in [&"orc", &"minotaur", &"medusa", &"cyclops"]:
		if expected_id not in final_ids:
			_fail("The final phase is missing %s." % expected_id)

	var medusa_entry: EnemySpawnEntry
	for entry in director.waves[3].enemies:
		if entry.enemy_data.id == &"medusa":
			medusa_entry = entry
			break
	if not medusa_entry or medusa_entry.scene_key != &"directional_ranged":
		_fail("Medusa should use the directional ranged behavior.")

	for entry in director.waves.back().enemies:
		await _validate_enemy_entry(spawner, entry)

	await _validate_boss_scene("res://scenes/bosses/orc_warlord.tscn", 4000.0)
	await _validate_boss_scene("res://scenes/bosses/corrupted_treant.tscn", 8000.0)

	var run_manager := RunManager.new()
	add_child(run_manager)
	await get_tree().process_frame
	if run_manager.boss_encounters.size() != 3:
		_fail("The run should contain three boss encounters.")
	elif not run_manager.boss_encounters.back().is_final_boss:
		_fail("The Corrupted Treant should be the final boss.")

	if _failures == 0:
		print("Horde progression tests passed.")
	get_tree().quit(_failures)


func _validate_boss_scene(path: String, expected_health: float) -> void:
	var scene := load(path) as PackedScene
	var boss := scene.instantiate() as MythicBoss
	add_child(boss)
	await get_tree().process_frame
	if not is_equal_approx(boss.health_component.max_health, expected_health):
		_fail("Boss at %s has unexpected health." % path)
	if boss.sprite.sprite_frames.get_frame_count(&"ATTACK") == 0:
		_fail("Boss at %s loaded an empty attack animation." % path)
	boss.free()


func _validate_enemy_entry(spawner: EnemySpawner, entry: EnemySpawnEntry) -> void:
	var enemy := spawner._get_enemy(entry)
	add_child(enemy)
	enemy.reset(Vector2(300.0, 300.0))
	await get_tree().process_frame
	if enemy.get("enemy_data") != entry.enemy_data:
		_fail("A spawn selection must keep its matching combat data for %s." % entry.enemy_data.id)
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if not health or not is_equal_approx(health.max_health, entry.enemy_data.max_health):
		_fail("Enemy %s did not apply its configured health." % entry.enemy_data.id)
	enemy.free()


func _entry_ids(wave: WaveData) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in wave.enemies:
		result.append(entry.enemy_data.id)
	return result


func _fail(message: String) -> void:
	_failures += 1
	push_error("Horde progression test: %s" % message)
