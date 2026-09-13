extends Node
## Valida a persistência de `intro_seen`, o roteamento do menu e o fluxo da introdução.

const SAVE_MANAGER_SCRIPT := preload("res://scripts/core/save_manager.gd")
const STORY_INTRO_SCRIPT := preload("res://scripts/ui/story_intro.gd")
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const STORY_INTRO_SCENE := "res://scenes/ui/story_intro.tscn"
const CHARACTER_SELECTION_SCENE := "res://scenes/ui/character_selection.tscn"
const TEST_SAVE_PATH := "user://story_intro_test_save.json"
const VIEWPORT_SIZE := Vector2(1280, 720)

var _failures := 0
var _original_save_path := ""
var _original_save_data: Dictionary = {}
var _tree: SceneTree
var _skip_target := ""
var _completion_target := ""


func _ready() -> void:
	# Guardado antes dos testes: concluir a introdução troca de cena e desanexa este nó.
	_tree = get_tree()
	_run_tests.call_deferred()


func _run_tests() -> void:
	_test_new_save_starts_without_intro()
	_test_intro_flag_persists()
	_test_migration_preserves_existing_progress()
	_test_menu_routing()
	await _test_intro_pages()
	# Precisa ser o último: concluir/pular dispara uma troca de cena.
	_test_finish_and_skip_target()

	_restore_save_manager()
	_remove_test_save()
	if _failures == 0:
		print("Story intro tests passed.")
	_tree.quit(_failures)


func _test_new_save_starts_without_intro() -> void:
	_remove_test_save()
	var manager := _make_isolated_manager()
	if manager.has_seen_intro():
		_fail("A new save should start with the intro unseen.")
	if manager.save_data.get("intro_seen") != false:
		_fail("A new save should store intro_seen as false.")
	manager.free()
	_remove_test_save()


func _test_intro_flag_persists() -> void:
	_remove_test_save()
	var manager := _make_isolated_manager()
	var currency_before: int = manager.get_currency()
	if not manager.set_intro_seen():
		_fail("Marking the intro as seen should succeed.")
	if not manager.has_seen_intro():
		_fail("The intro flag should be true right after being set.")
	if manager.get_currency() != currency_before \
			or not manager.has_unlocked_character("eirik"):
		_fail("Marking the intro as seen should not touch coins or unlocked characters.")
	manager.free()

	var reloaded := _make_isolated_manager()
	if not reloaded.has_seen_intro():
		_fail("The intro flag should survive a reload of the save file.")
	if not reloaded.set_intro_seen():
		_fail("Marking an already-seen intro again should stay successful.")
	reloaded.free()
	_remove_test_save()


func _test_migration_preserves_existing_progress() -> void:
	_remove_test_save()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"save_version": 5,
		"currency": 120,
		"unlocked_characters": ["eirik", "neferu", "perseus", "kratos"],
		"unlocked_weapons": ["mjolnir", "blades_of_chaos"],
		"settings": {"master_volume": 0.5, "music_volume": 0.4, "fullscreen": true},
	}))
	file = null

	var manager := _make_isolated_manager()
	if manager.has_seen_intro():
		_fail("A save without the intro key should migrate to an unseen intro.")
	if manager.get_currency() != 120 or not manager.has_unlocked_character("kratos") \
			or not manager.is_unlocked(&"weapon", &"blades_of_chaos"):
		_fail("The intro migration should preserve coins and unlocked content.")
	if not is_equal_approx(manager.get_master_volume(), 0.5) \
			or not is_equal_approx(manager.get_music_volume(), 0.4) \
			or not manager.is_fullscreen_enabled():
		_fail("The intro migration should preserve existing settings.")
	manager.free()
	_remove_test_save()


func _test_menu_routing() -> void:
	if not ResourceLoader.exists(STORY_INTRO_SCENE):
		_fail("The story intro scene should exist at %s." % STORY_INTRO_SCENE)
		return

	var menu := (load(MAIN_MENU_SCENE) as PackedScene).instantiate() as Control
	add_child(menu)

	_patch_save_manager(false)
	if menu._resolve_play_scene() != STORY_INTRO_SCENE:
		_fail("Playing with an unseen intro should open the story intro.")

	_patch_save_manager(true)
	if menu._resolve_play_scene() != STORY_INTRO_SCENE:
		_fail("Playing should open the story intro even after it has been seen.")

	menu.queue_free()
	_remove_test_save()


func _test_intro_pages() -> void:
	_patch_save_manager(false)
	var intro := _make_intro()
	await get_tree().process_frame

	_check_page_layout(intro, 1)

	var page_count: int = STORY_INTRO_SCRIPT.PAGES.size()
	if page_count != 4:
		_fail("The intro should show exactly four narrative pages.")
	if intro.progress_label.text != "1 / 4":
		_fail("The first page should show the 1 / 4 progress indicator.")
	if intro.back_button.visible:
		_fail("The back button should stay hidden on the first page.")
	if intro.title_label.text != String(STORY_INTRO_SCRIPT.PAGES[0]["title"]):
		_fail("The first page should show the first title.")

	for index in range(page_count):
		intro._go_to_page(index)
		intro._apply_current_page()
		var page: Dictionary = STORY_INTRO_SCRIPT.PAGES[index]
		if String(page.get("title", "")).is_empty() or String(page.get("body", "")).is_empty():
			_fail("Page %d should have a title and a narrative text." % (index + 1))
		if intro.progress_label.text != "%d / %d" % [index + 1, page_count]:
			_fail("Page %d should show its own progress indicator." % (index + 1))
		if intro.back_button.visible != (index > 0):
			_fail("The back button should only appear from the second page on.")
		if not ResourceLoader.exists(String(page.get("image", ""))):
			# Não é falha: a UI precisa sobreviver a uma arte ainda não entregue.
			print("Story intro: missing art %s, using the fallback background." % page.get("image", ""))
			if intro.page_image.visible:
				_fail("A missing page image should hide the texture and keep the fallback.")

	await get_tree().process_frame
	_check_page_layout(intro, page_count)

	if intro.next_button.text != "COMEÇAR":
		_fail("The last page should turn the next button into the confirmation button.")

	# Navegação rápida não pode travar o fade nem perder a página alvo.
	intro._navigate(-1)
	intro._navigate(-1)
	intro._navigate(1)
	if intro.page_index != 2:
		_fail("Fast navigation should keep the page index consistent.")
	intro._go_to_page(0)
	if intro.back_button.visible or intro.next_button.text != "PROXIMO":
		_fail("Going back to the first page should restore the first-page footer.")

	intro.queue_free()


func _test_finish_and_skip_target() -> void:
	_remove_test_save()
	_patch_save_manager(false)

	# As duas telas são criadas antes de qualquer conclusão: concluir dispara uma
	# troca de cena e a partir daí a árvore de teste já está sendo descartada.
	var skipped := _make_intro()
	var completed := _make_intro()
	skipped.intro_finished.connect(_on_skip_finished)
	completed.intro_finished.connect(_on_completion_finished)

	skipped.skip_button.pressed.emit()
	if _skip_target != CHARACTER_SELECTION_SCENE:
		_fail("Skipping should send the player to character selection.")
	if not SaveManager.has_seen_intro():
		_fail("Skipping should mark the intro as seen.")

	_remove_test_save()
	_patch_save_manager(false)

	for _i in range(STORY_INTRO_SCRIPT.PAGES.size()):
		completed._advance()
	if completed.page_index != STORY_INTRO_SCRIPT.PAGES.size() - 1:
		_fail("Advancing should stop on the last page before finishing.")
	if _completion_target != CHARACTER_SELECTION_SCENE:
		_fail("Finishing the last page should send the player to character selection.")
	if not SaveManager.has_seen_intro():
		_fail("Finishing the intro should mark it as seen.")

	var stored := _read_test_save()
	if stored.get("intro_seen") != true:
		_fail("Finishing the intro should persist intro_seen in the save file.")
	if not stored.has("currency") or not stored.has("unlocked_characters"):
		_fail("Persisting the intro flag should keep the rest of the save intact.")


func _on_skip_finished(next_scene_path: String) -> void:
	_skip_target = next_scene_path


func _on_completion_finished(next_scene_path: String) -> void:
	_completion_target = next_scene_path


## A introdução é medida dentro de um viewport de 1280x720, a resolução base do projeto.
func _check_page_layout(intro: Control, page_number: int) -> void:
	if not intro.size.is_equal_approx(VIEWPORT_SIZE):
		_fail("The intro should fill the whole %s screen." % VIEWPORT_SIZE)
	var rects := {
		"title": intro.title_label.get_global_rect(),
		"narrative text": intro.body_label.get_global_rect(),
		"progress indicator": intro.progress_label.get_global_rect(),
		"buttons": (intro.get_node("Footer/ButtonsRow") as Control).get_global_rect(),
		"keyboard hint": (intro.get_node("Footer/NavigationHint") as Control).get_global_rect(),
	}
	var screen := Rect2(Vector2.ZERO, VIEWPORT_SIZE)
	for name in rects:
		var rect: Rect2 = rects[name]
		if not screen.encloses(rect):
			_fail("Page %d: the %s should stay inside the screen." % [page_number, name])
	var order := ["title", "narrative text", "progress indicator", "buttons", "keyboard hint"]
	for index in range(order.size() - 1):
		var current: Rect2 = rects[order[index]]
		var following: Rect2 = rects[order[index + 1]]
		if current.end.y > following.position.y:
			_fail("Page %d: the %s should not overlap the %s." % [
				page_number, order[index], order[index + 1],
			])


func _make_intro() -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(VIEWPORT_SIZE)
	add_child(viewport)
	var intro := (load(STORY_INTRO_SCENE) as PackedScene).instantiate() as Control
	viewport.add_child(intro)
	return intro


func _make_isolated_manager() -> Node:
	var manager := SAVE_MANAGER_SCRIPT.new()
	manager.save_path = TEST_SAVE_PATH
	manager.apply_runtime_settings = false
	add_child(manager)
	return manager


func _patch_save_manager(intro_seen: bool) -> void:
	if _original_save_path.is_empty():
		_original_save_path = SaveManager.save_path
		_original_save_data = SaveManager.save_data
	SaveManager.save_path = TEST_SAVE_PATH
	var data: Dictionary = SaveManager._make_defaults()
	data["intro_seen"] = intro_seen
	SaveManager.save_data = data


func _restore_save_manager() -> void:
	if _original_save_path.is_empty():
		return
	SaveManager.save_path = _original_save_path
	SaveManager.save_data = _original_save_data


func _read_test_save() -> Dictionary:
	if not FileAccess.file_exists(TEST_SAVE_PATH):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(TEST_SAVE_PATH)) != OK:
		return {}
	var parsed = json.get_data()
	return parsed if parsed is Dictionary else {}


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _fail(message: String) -> void:
	_failures += 1
	push_error("Story intro test: %s" % message)
