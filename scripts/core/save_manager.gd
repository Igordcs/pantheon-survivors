extends Node
## Persistência da economia e dos desbloqueios permanentes.

signal currency_changed(new_balance: int)
signal unlock_changed(category: StringName, content_id: StringName)
signal loadout_changed
signal settings_changed

const SAVE_PATH := "user://save_data.json"
const SAVE_VERSION := 6
const INITIAL_CHARACTER_IDS := ["eirik", "neferu", "perseus"]
const INITIAL_WEAPON_IDS := ["mjolnir"]

var save_path: String = SAVE_PATH
var apply_runtime_settings := true

var save_data: Dictionary = {
	"save_version": SAVE_VERSION,
	"currency": 0,
	"unlocked_weapons": ["mjolnir"],
	"unlocked_relics": ["speed_relic"],
	"unlocked_characters": ["eirik", "neferu", "perseus"],
	"unlocked_items": [],
	"equipped_items": [],
	"intro_seen": false,
	"settings": {
		"master_volume": 0.8,
		"music_volume": 0.8,
		"fullscreen": false,
	},
}


func _ready() -> void:
	load_game()
	if apply_runtime_settings:
		apply_settings.call_deferred()


func _make_defaults() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"currency": 0,
		"unlocked_weapons": INITIAL_WEAPON_IDS.duplicate(),
		"unlocked_relics": ["speed_relic"],
		"unlocked_characters": INITIAL_CHARACTER_IDS.duplicate(),
		"unlocked_items": [],
		"equipped_items": [],
		"intro_seen": false,
		"settings": {
			"master_volume": 0.8,
			"music_volume": 0.8,
			"fullscreen": false,
		},
	}


func get_master_volume() -> float:
	return clampf(float(_get_settings().get("master_volume", 0.8)), 0.0, 1.0)


func get_music_volume() -> float:
	return clampf(float(_get_settings().get("music_volume", 0.8)), 0.0, 1.0)


func is_fullscreen_enabled() -> bool:
	return bool(_get_settings().get("fullscreen", false))


func get_unlocked_items() -> Array[StringName]:
	var result: Array[StringName] = []
	for value in save_data.get("unlocked_items", []): result.append(StringName(value))
	return result


func get_equipped_items() -> Array[StringName]:
	var result: Array[StringName] = []
	for value in save_data.get("equipped_items", []): result.append(StringName(value))
	return result


func equip_item(item_id: StringName) -> bool:
	if not is_unlocked(&"item", item_id) or not ItemCatalog.is_shop_item(item_id): return false
	var equipped: Array = save_data.get("equipped_items", [])
	if String(item_id) in equipped: return true
	if equipped.size() >= 3: return false
	equipped.append(String(item_id)); save_data["equipped_items"] = equipped
	if not save_game(): equipped.erase(String(item_id)); return false
	loadout_changed.emit()
	return true


func unequip_item(item_id: StringName) -> bool:
	var equipped: Array = save_data.get("equipped_items", [])
	if String(item_id) not in equipped: return false
	equipped.erase(String(item_id)); save_data["equipped_items"] = equipped
	if not save_game(): equipped.append(String(item_id)); return false
	loadout_changed.emit()
	return true


func set_master_volume(value: float) -> bool:
	return _set_setting("master_volume", clampf(value, 0.0, 1.0))


func set_music_volume(value: float) -> bool:
	return _set_setting("music_volume", clampf(value, 0.0, 1.0))


func set_fullscreen_enabled(enabled: bool) -> bool:
	return _set_setting("fullscreen", enabled)


func apply_settings() -> void:
	_apply_master_volume(get_master_volume())
	_apply_music_volume(get_music_volume())
	_apply_fullscreen(is_fullscreen_enabled())


func _get_settings() -> Dictionary:
	var stored = save_data.get("settings", {})
	if not (stored is Dictionary):
		stored = {}
		save_data["settings"] = stored
	return stored


func _set_setting(key: String, value: Variant) -> bool:
	var settings := _get_settings()
	var previous_value = settings.get(key)
	settings[key] = value
	save_data["settings"] = settings
	if apply_runtime_settings:
		_apply_setting(key, value)
	if not save_game():
		settings[key] = previous_value
		save_data["settings"] = settings
		if apply_runtime_settings:
			_apply_setting(key, previous_value)
		return false
	settings_changed.emit()
	return true


func _apply_setting(key: String, value: Variant) -> void:
	match key:
		"master_volume": _apply_master_volume(float(value))
		"music_volume": _apply_music_volume(float(value))
		"fullscreen": _apply_fullscreen(bool(value))


func _apply_master_volume(value: float) -> void:
	var master_bus_idx := AudioServer.get_bus_index("Master")
	if master_bus_idx == -1:
		return
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(master_bus_idx, value <= 0.001)


func _apply_music_volume(value: float) -> void:
	var music_manager := get_node_or_null("/root/MusicManager")
	if music_manager and music_manager.has_method("set_music_volume"):
		music_manager.set_music_volume(value)


func _apply_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		var mode := DisplayServer.window_get_mode()
		if mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN \
				and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var viewport_width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var viewport_height := int(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	var window_size := Vector2i(viewport_width, viewport_height)
	DisplayServer.window_set_size(window_size)
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(screen_position + (screen_size - window_size) / 2)


func has_seen_intro() -> bool:
	return bool(save_data.get("intro_seen", false))


func set_intro_seen() -> bool:
	if has_seen_intro():
		return true
	save_data["intro_seen"] = true
	if not save_game():
		save_data["intro_seen"] = false
		return false
	return true


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
	elif shop_item.id == &"kratos":
		_unlock(&"weapon", &"blades_of_chaos", false)
	if not save_game():
		save_data = previous_unlocks
		return false
	currency_changed.emit(get_currency())
	unlock_changed.emit(category, shop_item.id)
	if shop_item.id == &"punisher":
		unlock_changed.emit(&"weapon", &"punisher_gun")
		unlock_changed.emit(&"weapon", &"punisher_grenade")
	elif shop_item.id == &"kratos":
		unlock_changed.emit(&"weapon", &"blades_of_chaos")
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
	var previous_version := int(save_data.get("save_version", 0))
	var defaults := _make_defaults()
	for key in defaults:
		if not save_data.has(key):
			save_data[key] = defaults[key]
	save_data["save_version"] = SAVE_VERSION
	save_data["currency"] = maxi(int(save_data.get("currency", 0)), 0)
	for key in ["unlocked_weapons", "unlocked_relics", "unlocked_characters", "unlocked_items", "equipped_items"]:
		var stored = save_data.get(key, [])
		var values: Array = stored if stored is Array else []
		var normalized: Array[String] = []
		for value in values:
			var id := String(value)
			if not id.is_empty() and id not in normalized:
				normalized.append(id)
		save_data[key] = normalized
	var unlocked_items: Array = save_data.get("unlocked_items", [])
	var equipped_items: Array = save_data.get("equipped_items", [])
	var valid_equipped: Array[String] = []
	for item_id in equipped_items:
		if item_id in unlocked_items and ItemCatalog.is_shop_item(StringName(item_id)) and item_id not in valid_equipped and valid_equipped.size() < 3:
			valid_equipped.append(item_id)
	save_data["equipped_items"] = valid_equipped
	save_data["intro_seen"] = bool(save_data.get("intro_seen", false))
	if previous_version < 4:
		var characters: Array = save_data.get("unlocked_characters", [])
		characters.erase("arthur")
		save_data["unlocked_characters"] = characters
	var weapons: Array = save_data.get("unlocked_weapons", [])
	if "anubiscurse" in weapons and "anubis_curse" not in weapons:
		weapons.append("anubis_curse")
	weapons.erase("anubiscurse")
	save_data["unlocked_weapons"] = weapons
	var stored_settings = save_data.get("settings", {})
	var settings: Dictionary = stored_settings if stored_settings is Dictionary else {}
	settings["master_volume"] = clampf(float(settings.get("master_volume", 0.8)), 0.0, 1.0)
	settings["music_volume"] = clampf(float(settings.get("music_volume", 0.8)), 0.0, 1.0)
	settings["fullscreen"] = bool(settings.get("fullscreen", false))
	save_data["settings"] = settings


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
