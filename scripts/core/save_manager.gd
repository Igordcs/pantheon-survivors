extends Node
## Persistência da economia e dos desbloqueios permanentes.

signal currency_changed(new_balance: int)
signal unlock_changed(category: StringName, content_id: StringName)

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 2
const INITIAL_CHARACTER_IDS := ["eirik", "arthur", "neferu", "perseus"]
const INITIAL_WEAPON_IDS := ["mjolnir"]

var save_path: String = SAVE_PATH

var save_data: Dictionary = {
	"save_version": SAVE_VERSION,
	"currency": 0,
	"unlocked_weapons": ["mjolnir"],
	"unlocked_relics": ["speed_relic"],
	"unlocked_characters": ["eirik", "arthur", "neferu", "perseus"],
	"unlocked_items": [],
}


func _ready() -> void:
	load_game()


func _make_defaults() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"currency": 0,
		"unlocked_weapons": INITIAL_WEAPON_IDS.duplicate(),
		"unlocked_relics": ["speed_relic"],
		"unlocked_characters": INITIAL_CHARACTER_IDS.duplicate(),
		"unlocked_items": [],
	}


func get_currency() -> int:
	return maxi(int(save_data.get("currency", 0)), 0)


func add_currency(amount: int) -> bool:
	if amount <= 0:
		return false
	var previous_balance := get_currency()
	save_data["currency"] = previous_balance + amount
	if not save_game():
		save_data["currency"] = previous_balance
		return false
	currency_changed.emit(get_currency())
	return true


func can_afford(cost: int) -> bool:
	return cost >= 0 and get_currency() >= cost


func has_unlocked_character(char_id: String) -> bool:
	return is_unlocked(&"character", StringName(char_id))


func unlock_character(char_id: String) -> void:
	_unlock(&"character", StringName(char_id), true)


func is_unlocked(category: StringName, content_id: StringName) -> bool:
	var key := _unlock_key(category)
	return not key.is_empty() and String(content_id) in save_data.get(key, [])


func try_purchase(shop_item: ShopItemData) -> bool:
	if not _is_catalog_product(shop_item):
		return false
	var category := _category_name(shop_item.category)
	if category.is_empty() or is_unlocked(category, shop_item.id) or not can_afford(shop_item.price):
		return false

	var previous_balance := get_currency()
	var previous_unlocks := save_data.duplicate(true)
	save_data["currency"] = previous_balance - shop_item.price
	_unlock(category, shop_item.id, false)
	if shop_item.id == &"punisher":
		_unlock(&"weapon", &"punisher_gun", false)
		_unlock(&"weapon", &"punisher_grenade", false)
	if not save_game():
		save_data = previous_unlocks
		return false
	currency_changed.emit(get_currency())
	unlock_changed.emit(category, shop_item.id)
	if shop_item.id == &"punisher":
		unlock_changed.emit(&"weapon", &"punisher_gun")
		unlock_changed.emit(&"weapon", &"punisher_grenade")
	return true


func save_game() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		return true
	else:
		push_warning("SaveManager: não foi possível salvar o progresso.")
	return false


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		save_data = _make_defaults()
		save_game()
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		save_data = _make_defaults()
		return
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	var parsed_data = json.get_data()
	if parse_error != OK or not (parsed_data is Dictionary):
		push_warning("SaveManager: save inválido; usando valores seguros.")
		save_data = _make_defaults()
		save_game()
		return

	save_data = parsed_data
	_migrate_save()
	save_game()


func _migrate_save() -> void:
	var defaults := _make_defaults()
	for key in defaults:
		if not save_data.has(key):
			save_data[key] = defaults[key]
	save_data["save_version"] = SAVE_VERSION
	save_data["currency"] = maxi(int(save_data.get("currency", 0)), 0)
	for key in ["unlocked_weapons", "unlocked_relics", "unlocked_characters", "unlocked_items"]:
		var stored = save_data.get(key, [])
		var values: Array = stored if stored is Array else []
		var normalized: Array[String] = []
		for value in values:
			var id := String(value)
			if not id.is_empty() and id not in normalized:
				normalized.append(id)
		save_data[key] = normalized
	var weapons: Array = save_data.get("unlocked_weapons", [])
	if "anubiscurse" in weapons and "anubis_curse" not in weapons:
		weapons.append("anubis_curse")
	weapons.erase("anubiscurse")
	save_data["unlocked_weapons"] = weapons


func _unlock(category: StringName, content_id: StringName, persist: bool) -> bool:
	var key := _unlock_key(category)
	if key.is_empty() or content_id.is_empty():
		return false
	var values: Array = save_data.get(key, [])
	if String(content_id) in values:
		return false
	var previous_values := values.duplicate()
	values.append(String(content_id))
	save_data[key] = values
	if persist:
		if not save_game():
			save_data[key] = previous_values
			return false
		unlock_changed.emit(category, content_id)
	return true


func _unlock_key(category: StringName) -> String:
	match category:
		&"character": return "unlocked_characters"
		&"weapon": return "unlocked_weapons"
		&"item": return "unlocked_items"
	return ""


func _category_name(category: int) -> StringName:
	match category:
		ShopItemData.Category.CHARACTER: return &"character"
		ShopItemData.Category.WEAPON: return &"weapon"
		ShopItemData.Category.ITEM: return &"item"
	return &""


func _is_catalog_product(shop_item: ShopItemData) -> bool:
	if not shop_item or shop_item.id.is_empty() or shop_item.price < 0 or not shop_item.content:
		return false
	for product in ShopCatalog.PRODUCTS:
		if product == shop_item:
			return true
	return false
