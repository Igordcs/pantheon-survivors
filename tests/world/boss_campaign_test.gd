extends Node

const EXPECTED_PHASE_BOSSES := {
	&"phase_1": [[&"king_slime", &"orc_warlord"], [&"cerberus"], [&"lernaean_hydra"]],
	&"phase_2": [[&"amheh"], [&"anubis"], [&"apophis"]],
	&"phase_3": [[&"corrupted_treant"], [&"jormungandr"], [&"fenrir"]],
}
const NEW_BOSS_IDS: Array[StringName] = [&"lernaean_hydra", &"amheh", &"anubis", &"apophis"]
const NEW_BOSS_SCRIPTS := {
	&"lernaean_hydra": "res://scripts/enemies/lernaean_hydra_boss.gd",
	&"amheh": "res://scripts/enemies/amheh_boss.gd",
	&"anubis": "res://scripts/enemies/anubis_boss.gd",
	&"apophis": "res://scripts/enemies/apophis_boss.gd",
}

var _failures := 0


func _ready() -> void:
	_validate_phase_rosters()
	_validate_random_first_anchor()
	await _validate_new_boss_scenes()
	if _failures == 0:
		print("Boss campaign tests passed.")
	get_tree().quit(_failures)


func _validate_phase_rosters() -> void:
	var scheduled: Dictionary[StringName, bool] = {}
	for phase_id in EXPECTED_PHASE_BOSSES:
		var phase := PhaseCatalog.get_phase(phase_id)
		var expected: Array = EXPECTED_PHASE_BOSSES[phase_id]
		var anchors := phase.get_anchors()
		if anchors.size() != 3:
			_fail("%s should schedule three boss encounters." % phase_id)
			continue
		for index in expected.size():
			var configured := anchors[index].get_boss_ids()
			if configured != expected[index]:
				_fail("%s anchor %d has an unexpected boss pool." % [phase_id, index + 1])
			for boss_id in configured:
				scheduled[boss_id] = true
				if ContentRegistry.get_boss_data(boss_id) == null:
					_fail("%s has no BossData." % boss_id)
				if ContentRegistry.get_boss_scene(boss_id) == null:
					_fail("%s has no boss scene." % boss_id)
	for boss_id in ContentRegistry.BOSSES:
		if not scheduled.has(boss_id):
			_fail("%s is registered but absent from the campaign." % boss_id)


func _validate_random_first_anchor() -> void:
	var selected: Dictionary[StringName, bool] = {}
	var phase := PhaseCatalog.get_phase(&"phase_1")
	# Godot's deterministic RNG maps these two seeds to opposite sides of the pool.
	for selection_seed in range(1, 3):
		var manager := RunManager.new()
		manager.boss_encounters = manager._encounters_from_phase(phase)
		manager._boss_rng.seed = selection_seed
		manager._resolve_boss_candidates()
		selected[manager.boss_encounters[0].id] = true
		manager.free()
	if not selected.has(&"king_slime") or not selected.has(&"orc_warlord"):
		_fail("Phase 1 first anchor should be able to select both configured bosses.")


func _validate_new_boss_scenes() -> void:
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	var player_health := HealthComponent.new()
	player_health.name = "HealthComponent"
	player.add_child(player_health)
	add_child(player)

	for boss_id in NEW_BOSS_IDS:
		var scene := ContentRegistry.get_boss_scene(boss_id)
		var boss := scene.instantiate() as DirectionalBoss
		boss.global_position = Vector2(300.0, 0.0)
		add_child(boss)
		await get_tree().process_frame
		for _frame in 2:
			await get_tree().physics_frame
		boss.set_physics_process(false)
		if boss.boss_data.id != boss_id:
			_fail("%s scene uses the wrong BossData." % boss_id)
		if boss.get_script().resource_path != NEW_BOSS_SCRIPTS[boss_id]:
			_fail("%s should use its exclusive combat script." % boss_id)
		if boss.sprite.texture == null:
			_fail("%s did not load its directional sprite." % boss_id)
		if boss.global_position.distance_to(Vector2.ZERO) >= 300.0:
			_fail("%s did not pursue the player." % boss_id)
		await _validate_exclusive_attacks(boss, boss_id)
		boss.free()
	await _validate_hazard_primitives(player, player_health)
	player.free()


func _validate_exclusive_attacks(boss: DirectionalBoss, boss_id: StringName) -> void:
	match boss_id:
		&"amheh":
			boss.call("_cast_devourer_flames")
			if (boss.get("_hazards") as Array).size() != 5:
				_fail("Amheh should summon five purple-fire areas in phase one.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.call("_cast_funeral_constellation")
			if (boss.get("_hazards") as Array).size() != 7:
				_fail("Amheh's funeral constellation should preserve one escape slot.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.call("_cast_consumed_horizon")
			if (boss.get("_hazards") as Array).size() != 2:
				_fail("Amheh's consumed horizon should combine an inverse ring and gravefire.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.health_component.current_health = boss.health_component.max_health * 0.4
			boss.call("_cast_devourer_flames")
			if (boss.get("_hazards") as Array).size() != 7:
				_fail("Amheh's second phase should expand the purple-fire pattern.")
		&"lernaean_hydra":
			boss.call("_cast_many_headed_strike")
			if (boss.get("_hazards") as Array).size() != 3:
				_fail("Hydra should begin with three sequential head strikes.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.call("_cast_swamp_eruption")
			if (boss.get("_hazards") as Array).size() != 6:
				_fail("Hydra's swamp eruption should create a six-step attack chain.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.call("_cast_head_sweep")
			if (boss.get("_hazards") as Array).size() != 1:
				_fail("Hydra's head sweep should create one ring with a safe opening.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.health_component.current_health = boss.health_component.max_health * 0.3
			boss.call("_update_head_tier")
			boss.call("_cast_many_headed_strike")
			if (boss.get("_hazards") as Array).size() != 5:
				_fail("Hydra should awaken two additional heads at low health.")
		&"anubis":
			boss.call("_prepare_weighing")
			if (boss.get("_hazards") as Array).size() != 1:
				_fail("Anubis's weighing should create one judgment field.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.call("_prepare_mummification")
			if (boss.get("_telegraphs") as Array).size() != 1:
				_fail("Anubis's mummification seal should have a visible cone telegraph.")
			boss.call("_clear_telegraphs")
			boss.call("_prepare_gates")
			if (boss.get("_gate_origins") as Array).size() != 4:
				_fail("Anubis should open four Gates of Duat in phase one.")
			boss.call("_clear_telegraphs")
			boss.health_component.current_health = boss.health_component.max_health * 0.4
			boss.call("_prepare_gates")
			if (boss.get("_gate_origins") as Array).size() != 6:
				_fail("Anubis should open six Gates of Duat in phase two.")
			boss.call("_fire_gates")
			if (boss.get("_hazards") as Array).size() != 6:
				_fail("Anubis's six gates should each fire a spectral projectile.")
		&"apophis":
			boss.call("_prepare_eclipse")
			if (boss.get("_hazards") as Array).size() != 1:
				_fail("Apophis's eclipse should create one inverse danger zone.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.call("_prepare_chaos_spiral")
			if (boss.get("_telegraphs") as Array).size() != 1:
				_fail("Apophis's chaos spiral should have a visible casting telegraph.")
			boss.call("_clear_telegraphs")
			boss.call("_spawn_poison_volley", Vector2.ZERO)
			if (boss.get("_hazards") as Array).size() != 3:
				_fail("Apophis should fire three poison projectiles in phase one.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.health_component.current_health = boss.health_component.max_health * 0.4
			boss.call("_spawn_poison_volley", Vector2.ZERO)
			if (boss.get("_hazards") as Array).size() != 4:
				_fail("Apophis should fire four poison projectiles in phase two.")
			boss.call("_cleanup_behavior")
			await get_tree().process_frame
			boss.set("_spiral_wave", 0)
			boss.set("_spiral_wave_count", 1)
			boss.call("_emit_spiral_wave")
			if (boss.get("_hazards") as Array).size() != 4:
				_fail("Apophis's second-phase chaos spiral should have four arms.")
	boss.call("_cleanup_behavior")
	await get_tree().process_frame


func _validate_hazard_primitives(player: CharacterBody2D, health: HealthComponent) -> void:
	player.global_position = Vector2.ZERO
	health.reset()
	var area := BossAreaHazard.new()
	add_child(area)
	area.setup(player, Vector2.ZERO, 50.0, 0.0, 12.0)
	area.set_process(false)
	area.call("_process", 0.01)
	if not is_equal_approx(health.current_health, health.max_health - 12.0):
		_fail("Circular boss hazards should apply their activation damage.")
	area.queue_free()
	await get_tree().process_frame

	health.reset()
	player.global_position = Vector2(70.0, 0.0)
	var safe_ring := BossRingHazard.new()
	add_child(safe_ring)
	safe_ring.setup(
		player, Vector2.ZERO, 40.0, 100.0, 0.0, 15.0,
		Color.PURPLE, Vector2.RIGHT, 60.0
	)
	safe_ring.set_process(false)
	safe_ring.call("_process", 0.01)
	if not is_equal_approx(health.current_health, health.max_health):
		_fail("A ring hazard must preserve its marked safe opening.")
	safe_ring.queue_free()
	await get_tree().process_frame

	var danger_ring := BossRingHazard.new()
	add_child(danger_ring)
	danger_ring.setup(player, Vector2.ZERO, 40.0, 100.0, 0.0, 15.0, Color.PURPLE)
	danger_ring.set_process(false)
	danger_ring.call("_process", 0.01)
	if not is_equal_approx(health.current_health, health.max_health - 15.0):
		_fail("A ring hazard should damage players standing outside its safe opening.")
	danger_ring.queue_free()


func _fail(message: String) -> void:
	_failures += 1
	push_error("Boss campaign test: %s" % message)
