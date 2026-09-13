extends Node

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var selection_scene := load("res://scenes/ui/character_selection.tscn") as PackedScene
	var selection := selection_scene.instantiate() as Control
	add_child(selection)
	await get_tree().process_frame

	var character_list := selection.get_node("VBoxContainer/ItemList") as ItemList
	var unlocked_count: int = SaveManager.save_data.get("unlocked_characters", []).size()
	if character_list.get_item_count() != unlocked_count:
		_fail("The selection should show every unlocked character.")
	var expected_columns := mini(unlocked_count, selection.MAX_CHARACTER_COLUMNS)
	if character_list.max_columns != expected_columns:
		_fail("The characters should use one column each, up to the row limit.")
	if character_list.fixed_icon_size.x < 96 or character_list.fixed_icon_size.y < 96:
		_fail("Character selection portraits should be at least 96 pixels.")
	if character_list.size.x < expected_columns * character_list.fixed_column_width:
		_fail("The character row should be wide enough to fit its columns on a single line.")

	# A caixa de seleção precisa de folgas iguais em cima e embaixo.
	var item_rect := character_list.get_item_rect(0)
	if item_rect.size.y < 120.0:
		_fail("The character row should stay tall enough for a portrait and its name.")
	var top_gap := item_rect.position.y
	var bottom_gap := character_list.size.y - item_rect.end.y
	if top_gap < 0.0 or absf(top_gap - bottom_gap) > 1.0:
		_fail("The selection highlight should leave the same gap above and below it.")

	# A fileira precisa ficar centralizada, e não encostada à esquerda.
	var row := character_list.get_parent() as Control
	var left_gap := character_list.position.x
	var right_gap := row.size.x - (character_list.position.x + character_list.size.x)
	if left_gap < 0.0 or absf(left_gap - right_gap) > 1.0:
		_fail("The character row should be horizontally centred on the screen.")
	if selection.get_node_or_null("VBoxContainer/DetailsContainer/Portrait") != null:
		_fail("The duplicated large character portrait should be removed from the details.")

	var weapon_icon := selection.get_node(
		"VBoxContainer/DetailsContainer/WeaponRow/WeaponIcon"
	) as TextureRect
	if weapon_icon.texture == null or weapon_icon.custom_minimum_size.x > 72.0:
		_fail("Character details should show a compact starting-weapon icon.")
	var health_icon := selection.get_node(
		"VBoxContainer/DetailsContainer/StatsContainer/HealthIcon"
	) as Label
	if health_icon.text != "♥":
		_fail("Health should use a heart icon.")
	var speed_icon := selection.get_node(
		"VBoxContainer/DetailsContainer/StatsContainer/SpeedIcon"
	) as TextureRect
	if speed_icon.texture == null:
		_fail("Movement speed should use a sandal icon.")

	if _failures == 0:
		print("Character selection layout tests passed.")
	get_tree().quit(_failures)


func _fail(message: String) -> void:
	_failures += 1
	push_error("Character selection layout test: %s" % message)
