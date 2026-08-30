extends Control
## CharacterSelection — Tela para escolher o personagem antes da Run.

@onready var character_list: ItemList = $VBoxContainer/ItemList
@onready var start_button: Button = $VBoxContainer/ButtonsContainer/StartButton
@onready var back_button: Button = $VBoxContainer/ButtonsContainer/BackButton
@onready var portrait: TextureRect = $VBoxContainer/DetailsContainer/Portrait
@onready var info_label: Label = $VBoxContainer/DetailsContainer/InfoLabel

var _unlocked_chars = []


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	character_list.item_selected.connect(_on_item_selected)
	
	_load_characters()
	character_list.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	if event is InputEventKey and event.echo:
		return

	var selection_step := 0
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		selection_step = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		selection_step = 1

	if selection_step != 0:
		_select_relative_character(selection_step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not start_button.disabled:
		get_viewport().set_input_as_handled()
		_on_start_pressed()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _load_characters() -> void:
	_unlocked_chars = SaveManager.save_data.get("unlocked_characters", [])
	character_list.clear()
	
	for char_id in _unlocked_chars:
		var data_path = "res://resources/characters/%s_data.tres" % char_id
		if ResourceLoader.exists(data_path):
			var data = load(data_path) as CharacterData
			if data:
				character_list.add_item(data.display_name, data.portrait)
				character_list.set_item_metadata(character_list.get_item_count() - 1, char_id)
				
	if character_list.get_item_count() > 0:
		character_list.select(0)
		_on_item_selected(0)


func _select_relative_character(step: int) -> void:
	var item_count := character_list.get_item_count()
	if item_count == 0:
		return
	var selected_items := character_list.get_selected_items()
	var current_index := selected_items[0] if not selected_items.is_empty() else 0
	var next_index := wrapi(current_index + step, 0, item_count)
	character_list.select(next_index)
	character_list.ensure_current_is_visible()
	_on_item_selected(next_index)


func _on_item_selected(index: int) -> void:
	var char_id = character_list.get_item_metadata(index) as StringName
	Global.selected_character_id = char_id
	
	var data_path = "res://resources/characters/%s_data.tres" % char_id
	var data = load(data_path) as CharacterData
	if data:
		portrait.texture = data.portrait
		portrait.visible = data.portrait != null

		var weapon_name := "Nenhuma"
		var weapon_description := "Sem arma inicial."
		if data.starting_weapon is WeaponData:
			weapon_name = data.starting_weapon.display_name
			weapon_description = data.starting_weapon.description

		info_label.text = "%s\n\nArma inicial: %s\n%s\n\nPerfil: %s\nVida: %d | Velocidade: %d" % [
			data.description,
			weapon_name,
			weapon_description,
			data.passive_description,
			data.base_health,
			data.base_speed
		]
	
	start_button.disabled = false


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
