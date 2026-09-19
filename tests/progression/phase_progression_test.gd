extends Node
## Valida o catálogo de fases, o desbloqueio persistido e a tela de seleção.

const SAVE_MANAGER_SCRIPT := preload("res://scripts/core/save_manager.gd")
const PHASE_SELECTION_SCENE := "res://scenes/ui/phase_selection.tscn"
const TEST_SAVE_PATH := "user://phase_progression_test_save.json"
const VIEWPORT_SIZE := Vector2(1280, 720)

var _tree: SceneTree
var _failures := 0
var _original_save_path := ""
var _original_save_data: Dictionary = {}


func _ready() -> void:
	# Guardado antes: iniciar uma fase troca de cena e desanexa este nó.
	_tree = get_tree()
	_run_tests.call_deferred()


func _run_tests() -> void:
	_test_catalog()
	_test_new_save_starts_locked()
	_test_completing_unlocks_the_next()
	_test_migration_repairs_progress()
	await _test_selection_screen()

	_restore_save_manager()
	_remove_test_save()
	if _failures == 0:
		print("Phase progression tests passed.")
	_tree.quit(_failures)


func _test_catalog() -> void:
	var phases := PhaseCatalog.get_phases()
	var scheduled_bosses: Dictionary[StringName, bool] = {}
	if phases.size() != 3:
		_fail("The campaign should expose the three phases from the lore.")
		return
	for index in range(phases.size()):
		var phase := phases[index]
		if phase.order != index + 1:
			_fail("Phases should be ordered by their campaign position.")
		if not phase.is_valid():
			_fail("Phase \"%s\" is not valid." % phase.phase_id)
		if not MapCatalog.has_map(phase.map_id):
			_fail("Phase \"%s\" points at a missing map." % phase.phase_id)
		# Toda Âncora precisa de um chefe que exista de fato.
		for anchor in phase.get_anchors():
			for boss_id in anchor.get_boss_ids():
				scheduled_bosses[boss_id] = true
				if ContentRegistry.get_boss_scene(boss_id) == null:
					_fail("Anchor \"%s\" of %s has no boss scene." % [boss_id, phase.phase_id])
		if phase.get_anchors().size() >= 2:
			var anchors := phase.get_anchors()
			for i in range(anchors.size() - 1):
				if anchors[i + 1].trigger_time <= anchors[i].trigger_time:
					_fail("%s: anchors should trigger in ascending order." % phase.phase_id)

	if PhaseCatalog.get_next_phase(phases[0].phase_id) != phases[1]:
		_fail("The phase after the first should be the second.")
	if PhaseCatalog.get_next_phase(phases[-1].phase_id) != null:
		_fail("The last phase should have no next phase.")
	if PhaseCatalog.get_phase(&"nao_existe") != phases[0]:
		_fail("An unknown phase id should fall back to the first phase.")

	var phase_1 := PhaseCatalog.get_phase(&"phase_1")
	var phase_2 := PhaseCatalog.get_phase(&"phase_2")
	if phase_1.get_anchor_count() != 3:
		_fail("Phase 1 should contain three boss encounters.")
	elif phase_1.get_anchors()[0].get_boss_ids() != [&"king_slime", &"orc_warlord"]:
		_fail("Phase 1 should draw its first boss from King Slime and Orc Warlord.")
	if phase_2.get_anchor_count() != 3:
		_fail("Phase 2 should contain three boss encounters.")
	else:
		var expected_phase_2: Array[StringName] = [&"amheh", &"anubis", &"apophis"]
		for index in expected_phase_2.size():
			if phase_2.get_anchors()[index].get_boss_ids() != [expected_phase_2[index]]:
				_fail("Phase 2 boss %d should be %s." % [index + 1, expected_phase_2[index]])
	for boss_id in ContentRegistry.BOSSES:
		if not scheduled_bosses.has(boss_id):
			_fail("Boss %s is registered but absent from the campaign." % boss_id)


func _test_new_save_starts_locked() -> void:
	_remove_test_save()
	var manager := _make_manager()
	if not manager.is_phase_unlocked(&"phase_1"):
		_fail("A new save should start with the first phase open.")
	if manager.is_phase_unlocked(&"phase_2") or manager.is_phase_unlocked(&"phase_3"):
		_fail("A new save should keep the later phases locked.")
	if not manager.get_completed_phases().is_empty():
		_fail("A new save should have no completed phase.")
	if manager.get_latest_unlocked_phase() != &"phase_1":
		_fail("The latest unlocked phase of a new save should be the first one.")
	manager.free()
	_remove_test_save()


func _test_completing_unlocks_the_next() -> void:
	_remove_test_save()
	var manager := _make_manager()
	var currency_before: int = manager.get_currency()

	if not manager.complete_phase(&"phase_1"):
		_fail("Completing the first phase should succeed.")
	if not manager.is_phase_completed(&"phase_1") or not manager.is_phase_unlocked(&"phase_2"):
		_fail("Completing a phase should seal it and open the next one.")
	if manager.is_phase_unlocked(&"phase_3"):
		_fail("Completing one phase should not skip ahead.")
	if manager.get_latest_unlocked_phase() != &"phase_2":
		_fail("The latest unlocked phase should follow the progress.")
	# Rejogar não pode alterar nada, conforme a lore.
	if not manager.complete_phase(&"phase_1"):
		_fail("Replaying a sealed phase should stay successful.")
	if manager.get_completed_phases().size() != 1:
		_fail("Replaying a phase should not duplicate the progress entry.")
	if manager.get_currency() != currency_before:
		_fail("Phase progress should not touch the player's coins.")
	if not manager.complete_phase(&"phase_2") or not manager.is_phase_unlocked(&"phase_3"):
		_fail("Completing the second phase should open the third.")
	if not manager.complete_phase(&"phase_3"):
		_fail("Completing the final phase should succeed.")
	manager.free()

	var reloaded := _make_manager()
	if not reloaded.is_phase_unlocked(&"phase_3") or not reloaded.is_phase_completed(&"phase_1"):
		_fail("Phase progress should survive a reload.")
	if reloaded.complete_phase(&"nao_existe"):
		_fail("An unknown phase should never be completed.")
	reloaded.free()
	_remove_test_save()


## Um save antigo, sem as chaves de fase, precisa abrir a campanha sem perder nada.
func _test_migration_repairs_progress() -> void:
	_remove_test_save()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"save_version": 7,
		"currency": 250,
		"unlocked_characters": ["eirik", "neferu", "perseus", "kratos"],
		"intro_seen": true,
		"completed_phases": ["phase_1"],
	}))
	file = null

	var manager := _make_manager()
	if manager.get_currency() != 250 or not manager.has_unlocked_character("kratos"):
		_fail("The phase migration should preserve coins and characters.")
	if not manager.has_seen_intro():
		_fail("The phase migration should preserve the intro flag.")
	if not manager.is_phase_unlocked(&"phase_1"):
		_fail("The first phase should always be unlocked after migrating.")
	# O save dizia que a fase 1 caiu, então a 2 tem de estar aberta.
	if not manager.is_phase_unlocked(&"phase_2"):
		_fail("Migration should reopen the phase after an already completed one.")
	if manager.is_phase_unlocked(&"phase_3"):
		_fail("Migration should not unlock phases beyond the recorded progress.")
	manager.free()
	_remove_test_save()


func _test_selection_screen() -> void:
	_patch_save_manager([], [])
	var screen := _make_screen()
	await get_tree().process_frame
	await get_tree().process_frame

	if screen._cards.size() != PhaseCatalog.get_phases().size():
		_fail("The selection should show one card per phase.")
	if screen.start_button.disabled:
		_fail("The first phase should be playable from a fresh save.")

	# Uma fase trancada não pode ser iniciada.
	var locked_index := PhaseCatalog.get_phase_index(&"phase_2")
	screen._select_phase(locked_index, false)
	if not screen.start_button.disabled:
		_fail("A locked phase should not be startable.")
	if screen.status_label.text != "TRANCADA":
		_fail("A locked phase should be labelled as locked.")

	# Com a primeira selada, a segunda abre e a tela já entra nela.
	_patch_save_manager(["phase_1", "phase_2"], ["phase_1"])
	var advanced := _make_screen()
	await get_tree().process_frame
	await get_tree().process_frame
	if advanced._selected_index != PhaseCatalog.get_phase_index(&"phase_2"):
		_fail("The screen should open on the most advanced unlocked phase.")
	if advanced.start_button.disabled:
		_fail("An unlocked phase should be startable.")
	advanced._select_phase(PhaseCatalog.get_phase_index(&"phase_1"), false)
	if advanced.start_button.text != "REVISITAR":
		_fail("A sealed phase should offer a replay.")
	if advanced.status_label.text != "SELADA":
		_fail("A sealed phase should be labelled as sealed.")

	# Confirmar leva a fase e o mapa para a sessão.
	advanced._select_phase(PhaseCatalog.get_phase_index(&"phase_2"), false)
	var phase := PhaseCatalog.get_phase(&"phase_2")
	Global.selected_phase_id = &""
	advanced._on_start_pressed()
	if Global.selected_phase_id != phase.phase_id or Global.selected_map_id != phase.map_id:
		_fail("Starting a phase should carry the phase and its map into the run.")

	if not advanced.size.is_equal_approx(VIEWPORT_SIZE):
		_fail("The screen should fill the whole %s viewport." % VIEWPORT_SIZE)
	var screen_rect := Rect2(Vector2.ZERO, VIEWPORT_SIZE)
	for path in ["Layout/CardRow", "Layout/DetailsPanel", "Layout/ButtonsContainer"]:
		var region := (advanced.get_node(path) as Control).get_global_rect()
		if not screen_rect.encloses(region):
			_fail("%s should stay inside the screen." % path)
	for path in ["Layout/TitleLabel", "Layout/ButtonsContainer/StartButton"]:
		if not (advanced.get_node(path) as Control).has_theme_font_override("font"):
			_fail("%s should use the game's pixel font." % path)

	screen.queue_free()
	advanced.queue_free()


func _make_screen() -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(VIEWPORT_SIZE)
	add_child(viewport)
	var screen := (load(PHASE_SELECTION_SCENE) as PackedScene).instantiate() as Control
	viewport.add_child(screen)
	return screen


func _make_manager() -> Node:
	var manager := SAVE_MANAGER_SCRIPT.new()
	manager.save_path = TEST_SAVE_PATH
	manager.apply_runtime_settings = false
	add_child(manager)
	return manager


func _patch_save_manager(unlocked: Array, completed: Array) -> void:
	if _original_save_path.is_empty():
		_original_save_path = SaveManager.save_path
		_original_save_data = SaveManager.save_data
	SaveManager.save_path = TEST_SAVE_PATH
	var data: Dictionary = SaveManager._make_defaults()
	if not unlocked.is_empty():
		data["unlocked_phases"] = unlocked.duplicate()
	data["completed_phases"] = completed.duplicate()
	SaveManager.save_data = data


func _restore_save_manager() -> void:
	if _original_save_path.is_empty():
		return
	SaveManager.save_path = _original_save_path
	SaveManager.save_data = _original_save_data


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _fail(message: String) -> void:
	_failures += 1
	push_error("Phase progression test: %s" % message)
