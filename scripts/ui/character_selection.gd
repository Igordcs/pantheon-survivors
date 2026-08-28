extends Control
## CharacterSelection — Tela para escolher o personagem antes da Run.

@onready var character_list: ItemList = $VBoxContainer/ItemList
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var info_label: Label = $VBoxContainer/InfoLabel

var _unlocked_chars = []


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	character_list.item_selected.connect(_on_item_selected)
	
	_load_characters()


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


func _on_item_selected(index: int) -> void:
	var char_id = character_list.get_item_metadata(index) as StringName
	Global.selected_character_id = char_id
	
	var data_path = "res://resources/characters/%s_data.tres" % char_id
	var data = load(data_path) as CharacterData
	if data:
		info_label.text = "Arma Inicial: %s\nPassiva: %s\nVida: %d | Velocidade: %d" % [
			data.starting_weapon.display_name if data.starting_weapon else "Nenhuma",
			data.passive_description,
			data.base_health,
			data.base_speed
		]
	
	start_button.disabled = false


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
