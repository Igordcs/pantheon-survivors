extends Node
## SaveManager — Gerencia a persistência de meta-progressão do jogo.

const SAVE_PATH = "user://save_data.json"
const INITIAL_CHARACTER_IDS := ["eirik", "arthur", "neferu"]

var save_data: Dictionary = {
	"currency": 0,
	"unlocked_weapons": ["mjolnir"],
	"unlocked_relics": ["thor_relic", "speed_relic"],
	"unlocked_characters": INITIAL_CHARACTER_IDS.duplicate()
}


func _ready() -> void:
	load_game()
	if _ensure_initial_characters_unlocked():
		save_game()


func _ensure_initial_characters_unlocked() -> bool:
	var unlocked_characters = save_data.get("unlocked_characters", [])
	if not unlocked_characters is Array:
		unlocked_characters = []

	var changed := false
	for character_id in INITIAL_CHARACTER_IDS:
		if character_id not in unlocked_characters:
			unlocked_characters.append(character_id)
			changed = true

	save_data["unlocked_characters"] = unlocked_characters
	return changed


func add_currency(amount: int) -> void:
	save_data["currency"] += amount
	save_game()


func has_unlocked_character(char_id: String) -> bool:
	return char_id in save_data.get("unlocked_characters", [])


func unlock_character(char_id: String) -> void:
	if not has_unlocked_character(char_id):
		save_data["unlocked_characters"].append(char_id)
		save_game()


func get_currency() -> int:
	return save_data.get("currency", 0)


func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_game() # Cria o arquivo com os defaults
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var err = json.parse(content)
		if err == OK:
			var data = json.get_data()
			if typeof(data) == TYPE_DICTIONARY:
				# Mescla os dados salvos com o default para não perder chaves novas
				for key in data.keys():
					save_data[key] = data[key]
