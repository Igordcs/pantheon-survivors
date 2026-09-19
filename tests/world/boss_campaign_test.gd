extends Node

const EXPECTED_PHASE_BOSSES := {
	&"phase_1": [[&"king_slime", &"orc_warlord"], [&"cerberus"], [&"lernaean_hydra"]],
	&"phase_2": [[&"amheh"], [&"anubis"], [&"apophis"]],
	&"phase_3": [[&"corrupted_treant"], [&"jormungandr"], [&"fenrir"]],
}
const NEW_BOSS_IDS: Array[StringName] = [&"lernaean_hydra", &"amheh", &"anubis", &"apophis"]

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
	player.add_child(player_health)
	add_child(player)

	for boss_id in NEW_BOSS_IDS:
		var scene := ContentRegistry.get_boss_scene(boss_id)
		var boss := scene.instantiate() as DirectionalBoss
		boss.global_position = Vector2(300.0, 0.0)
		add_child(boss)
		await get_tree().process_frame
		await get_tree().physics_frame
		if boss.boss_data.id != boss_id:
			_fail("%s scene uses the wrong BossData." % boss_id)
		if boss.sprite.texture == null:
			_fail("%s did not load its directional sprite." % boss_id)
		if boss.global_position.distance_to(Vector2.ZERO) >= 300.0:
			_fail("%s did not pursue the player." % boss_id)
		boss.free()
	player.free()


func _fail(message: String) -> void:
	_failures += 1
	push_error("Boss campaign test: %s" % message)
