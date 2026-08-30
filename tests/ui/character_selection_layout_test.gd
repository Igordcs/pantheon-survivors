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
	if character_list.get_item_count() != 4:
		_fail("The initial selection should show all four characters.")
	if character_list.max_columns != 4:
		_fail("The initial characters should use four horizontal columns.")
	if character_list.fixed_icon_size.x < 96 or character_list.fixed_icon_size.y < 96:
		_fail("Character selection portraits should be at least 96 pixels.")
	if character_list.size.x < 1000.0 or character_list.size.y < 140.0:
		_fail("Character selection should use the available screen area.")
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
