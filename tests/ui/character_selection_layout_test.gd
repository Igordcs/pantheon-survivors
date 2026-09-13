extends Node
## Valida o layout e o comportamento da tela de seleção de personagem em 1280x720.

const SELECTION_SCENE := "res://scenes/ui/character_selection.tscn"
const VIEWPORT_SIZE := Vector2(1280, 720)

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var selection := _make_selection()
	await get_tree().process_frame
	await get_tree().process_frame

	_test_cards(selection)
	_test_theme(selection)
	_test_layout(selection)
	_test_selection_updates_details(selection)

	if _failures == 0:
		print("Character selection layout tests passed.")
	get_tree().quit(_failures)


func _test_cards(selection: Control) -> void:
	var unlocked: int = SaveManager.save_data.get("unlocked_characters", []).size()
	if selection._cards.size() != unlocked:
		_fail("The selection should show one card per unlocked character.")
	if selection._cards.is_empty():
		return
	if selection._selected_index != 0:
		_fail("The first character should start selected.")
	if selection.start_button.disabled:
		_fail("Starting the run should be enabled once a character is selected.")

	for card in selection._cards:
		var portrait := card.get_node_or_null("Content/Portrait") as TextureRect
		if portrait == null or portrait.texture == null:
			_fail("Every character card should show a portrait.")
			continue
		# Pixel art borra com filtro linear; o retrato precisa de nearest.
		if portrait.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			_fail("Card portraits should use nearest-neighbour filtering.")
		if portrait.custom_minimum_size.x < 96.0 or portrait.custom_minimum_size.y < 96.0:
			_fail("Card portraits should be at least 96 pixels.")

	# O retrato grande duplicado não deve voltar ao painel de detalhes.
	var identity := selection.get_node("Layout/DetailsContainer/IdentityPanel/Identity")
	for child in identity.get_children():
		if child is TextureRect:
			_fail("The details panel should not duplicate the character portrait.")


func _test_theme(selection: Control) -> void:
	var pixel_font_nodes := {
		"Layout/TitleLabel": "title",
		"Layout/NavigationHint": "navigation hint",
		"Layout/ButtonsContainer/StartButton": "start button",
		"Layout/ButtonsContainer/BackButton": "back button",
	}
	for path in pixel_font_nodes:
		var node := selection.get_node(path) as Control
		if not node.has_theme_font_override("font"):
			_fail("The %s should use the game's pixel font." % pixel_font_nodes[path])
	for path in ["Layout/ButtonsContainer/StartButton", "Layout/ButtonsContainer/BackButton"]:
		var button := selection.get_node(path) as Button
		if not button.has_theme_stylebox_override("normal") \
				or not button.has_theme_stylebox_override("focus"):
			_fail("Buttons should use the same styling as the main menu.")
	if selection.get_node_or_null("BackgroundArt") == null \
			or selection.get_node_or_null("EmberParticles") == null:
		_fail("The screen should keep the background art and the ember particles.")


func _test_layout(selection: Control) -> void:
	if not selection.size.is_equal_approx(VIEWPORT_SIZE):
		_fail("The screen should fill the whole %s viewport." % VIEWPORT_SIZE)
	if selection._cards.is_empty():
		return

	var layout := selection.get_node("Layout") as Control
	var row := selection.card_row as Control

	# Os cards ficam em uma única fileira centralizada.
	var first: Rect2 = selection._cards[0].get_global_rect()
	var last: Rect2 = selection._cards[-1].get_global_rect()
	if not is_equal_approx(first.position.y, last.position.y):
		_fail("All character cards should sit on a single row.")
	var left_gap := row.position.x
	var right_gap := layout.size.x - (row.position.x + row.size.x)
	if left_gap < 0.0 or absf(left_gap - right_gap) > 1.0:
		_fail("The character row should be horizontally centred.")

	var screen := Rect2(Vector2.ZERO, VIEWPORT_SIZE)
	var regions := {
		"card row": row.get_global_rect(),
		"details": (selection.get_node("Layout/DetailsContainer") as Control).get_global_rect(),
		"buttons": (selection.get_node("Layout/ButtonsContainer") as Control).get_global_rect(),
	}
	for region_name in regions:
		if not screen.encloses(regions[region_name]):
			_fail("The %s should stay inside the screen." % region_name)
	if regions["card row"].end.y > regions["details"].position.y:
		_fail("The card row should not overlap the details panels.")
	if regions["details"].end.y > regions["buttons"].position.y:
		_fail("The details panels should not overlap the buttons.")


func _test_selection_updates_details(selection: Control) -> void:
	if selection._cards.size() < 2:
		return
	selection._select_relative_character(1)
	var data: CharacterData = selection._characters[1]

	if Global.selected_character_id != data.id:
		_fail("Selecting a card should update the character chosen for the run.")
	if selection.name_label.text != data.display_name:
		_fail("The identity panel should show the selected character's name.")
	if selection.oath_label.text.is_empty() or selection.patron_label.text.is_empty():
		_fail("The identity panel should show the oath and the patron god.")
	if not is_equal_approx(selection.health_bar.value, data.base_health) \
			or not is_equal_approx(selection.speed_bar.value, data.base_speed):
		_fail("The stat bars should reflect the selected character.")
	if selection.health_bar.value > selection.health_bar.max_value \
			or selection.speed_bar.value > selection.speed_bar.max_value:
		_fail("The stat bars should never overflow their maximum.")
	if selection.weapon_name.text.is_empty():
		_fail("The loadout panel should show the starting weapon.")

	selection._select_relative_character(-1)
	if Global.selected_character_id != selection._characters[0].id:
		_fail("Navigating back should restore the previous character.")


func _make_selection() -> Control:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(VIEWPORT_SIZE)
	add_child(viewport)
	var selection := (load(SELECTION_SCENE) as PackedScene).instantiate() as Control
	viewport.add_child(selection)
	return selection


func _fail(message: String) -> void:
	_failures += 1
	push_error("Character selection layout test: %s" % message)
