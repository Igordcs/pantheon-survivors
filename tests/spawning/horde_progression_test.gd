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
	await _validate_directional_boss_scene("res://scenes/bosses/cerberus.tscn", 3600.0)
	await _validate_directional_boss_scene("res://scenes/bosses/jormungandr.tscn", 9500.0)

	var run_manager := RunManager.new()
	run_manager.boss_selection_seed = 12345
	add_child(run_manager)
	await get_tree().process_frame
	var medium_encounter := _find_encounter_at(run_manager.boss_encounters, 390.0)
	var final_encounter := _find_final_encounter(run_manager.boss_encounters)
	if medium_encounter == null:
		_fail("The run should contain a medium boss encounter at 06:30.")
	else:
		_validate_boss_pool(
			medium_encounter,
			[&"orc_warlord", &"cerberus"],
			"medium"
		)
	if final_encounter == null:
		_fail("The run should contain a final boss encounter.")
	else:
		_validate_boss_pool(
			final_encounter,
			[&"corrupted_treant", &"jormungandr"],
			"final"
		)

	run_manager.enemy_spawner = spawner
	if medium_encounter:
		run_manager._configure_horde_for_boss(medium_encounter)
		if not spawner.is_spawning():
			_fail("Regular enemies should spawn during a non-final boss fight.")
	if final_encounter:
		run_manager._configure_horde_for_boss(final_encounter)
		if spawner.is_spawning():
			_fail("Regular enemies should not spawn during the final boss fight.")

	var treant_scene := load("res://scenes/bosses/corrupted_treant.tscn") as PackedScene
	var treant := treant_scene.instantiate() as MythicBoss
	if treant.minion_scenes.is_empty():
		_fail("Final bosses may still summon enemies as part of their own attacks.")
	treant.free()

	if _failures == 0:
		print("Horde progression tests passed.")
	get_tree().quit(_failures)


func _validate_boss_scene(path: String, expected_health: float) -> void:
	var scene := load(path) as PackedScene
	var boss := scene.instantiate() as MythicBoss
	if path.ends_with("corrupted_treant.tscn"):
		boss.global_position = Vector2(300.0, 0.0)
	add_child(boss)
	await get_tree().process_frame
	if not is_equal_approx(boss.health_component.max_health, expected_health):
		_fail("Boss at %s has unexpected health." % path)
	if boss.sprite.sprite_frames.get_frame_count(&"ATTACK") == 0:
		_fail("Boss at %s loaded an empty attack animation." % path)
	if path.ends_with("corrupted_treant.tscn"):
		if boss.sprite.sprite_frames.get_frame_count(&"SPAWN") != 11:
			_fail("Corrupted Treant should play all ground-up frames only when spawning.")
		if boss.sprite.sprite_frames.get_frame_count(&"IDLE") != 1:
			_fail("Corrupted Treant idle should keep only its fully emerged frame.")
		if boss.boss_data.speed <= 0.0:
			_fail("Corrupted Treant should move toward the player.")
		boss.call("_enter_chasing")
		for _frame in 2:
			await get_tree().physics_frame
		if boss.global_position.distance_to(Vector2.ZERO) >= 300.0:
			_fail("Corrupted Treant did not chase the player.")
	boss.free()


func _validate_directional_boss_scene(path: String, expected_health: float) -> void:
	var scene := load(path) as PackedScene
	var boss := scene.instantiate() as DirectionalBoss
	boss.global_position = Vector2(300.0, 0.0)
	add_child(boss)
	await get_tree().process_frame
	for _frame in 2:
		await get_tree().physics_frame
	if not is_equal_approx(boss.health_component.max_health, expected_health):
		_fail("Boss at %s has unexpected health." % path)
	if boss.sprite.texture == null:
		_fail("Boss at %s did not load its directional sprite." % path)
	if boss.boss_data.speed <= 0.0:
		_fail("Boss at %s should move toward the player." % path)
	if boss.global_position.distance_to(Vector2.ZERO) >= 300.0:
		_fail("Boss at %s did not chase the player." % path)
	if path.ends_with("jormungandr.tscn"):
		boss.call("_execute_radial_magic")
		var radial_projectiles := get_tree().get_nodes_in_group("boss_magic_projectiles")
		if radial_projectiles.size() != 36:
			_fail("Jormungandr should fire exactly 36 radial magic projectiles.")
		var emitted_angles: Dictionary[int, bool] = {}
		for projectile in radial_projectiles:
			var direction: Vector2 = projectile.get("direction")
			var angle_degrees := posmod(roundi(rad_to_deg(direction.angle())), 360)
			emitted_angles[angle_degrees] = true
			projectile.queue_free()
		for expected_angle in range(0, 360, 10):
			if not emitted_angles.has(expected_angle):
				_fail("Jormungandr's radial barrage is missing the %d-degree projectile." % expected_angle)
	boss.free()


func _validate_boss_pool(
	encounter: BossEncounterData,
	expected_ids: Array[StringName],
	label: String
) -> void:
	var candidate_ids: Array[StringName] = []
	for candidate in encounter.candidates:
		candidate_ids.append(candidate.id)
	for expected_id in expected_ids:
		if expected_id not in candidate_ids:
			_fail("The %s boss pool is missing %s." % [label, expected_id])
	if encounter.id not in candidate_ids:
		_fail("The selected %s boss does not belong to its pool." % label)


func _find_encounter_at(
	encounters: Array[BossEncounterData],
	trigger_time: float
) -> BossEncounterData:
	for encounter in encounters:
		if is_equal_approx(encounter.trigger_time, trigger_time):
			return encounter
	return null


func _find_final_encounter(encounters: Array[BossEncounterData]) -> BossEncounterData:
	for encounter in encounters:
		if encounter.is_final_boss:
			return encounter
	return null


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
