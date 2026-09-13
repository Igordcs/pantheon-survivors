extends Node

const SAVE_MANAGER_SCRIPT := preload("res://scripts/core/save_manager.gd")
const TEST_SAVE_PATH := "user://shop_and_loot_test_save.json"

var _failures := 0


func _ready() -> void:
	_test_catalog()
	_test_loot_rolls()
	_test_drop_distribution()
	_test_catalog_validation()
	_test_save_and_purchases()
	_test_legacy_save_migration()
	_test_settings_persistence()
	await _test_coin_pooling()
	_test_coin_single_collection()
	if _failures == 0:
		print("Shop and loot tests passed.")
	get_tree().quit(_failures)


func _test_catalog() -> void:
	var characters := ShopCatalog.get_products(ShopItemData.Category.CHARACTER)
	var weapons := ShopCatalog.get_products(ShopItemData.Category.WEAPON)
	var items := ShopCatalog.get_products(ShopItemData.Category.ITEM)
	var character_ids: Array[StringName] = []
	for character in characters: character_ids.append(character.id)
	if characters.size() != 3 or &"punisher" not in character_ids \
			or &"arthur" not in character_ids or &"kratos" not in character_ids:
		_fail("Character catalog should contain the Punisher, King Arthur and Kratos.")
	var weapon_ids: Array[StringName] = []
	for product in weapons:
		weapon_ids.append(product.id)
	for expected in [&"anubis_curse", &"gungnir", &"sumarbrander", &"leviathan_axe"]:
		if expected not in weapon_ids:
			_fail("Weapon catalog is missing %s." % expected)
	if items.size() != 11:
		_fail("The shop should contain only the 11 special-power and synergy items.")
	for item in items:
		if item.id == &"excalibur_scabbard" or not item.icon or ItemCatalog.is_fundamental(item.id):
			_fail("The shop contains a removed, fundamental or iconless item.")
	if ItemCatalog.get_all().size() != 18 or ItemCatalog.get_fundamentals().size() != 7:
		_fail("The complete catalog should contain 18 items, including seven fundamentals.")
	var sandals := ItemCatalog.get_item(&"hermes_sandals")
	if not sandals or sandals.max_level != 5 \
			or not is_equal_approx(sandals.get_value_for_level(5), 0.25):
		_fail("Hermes Sandals should have five movement-speed levels.")


func _test_loot_rolls() -> void:
	var loot := LootManager.new()
	loot.regular_drop_chance = 1.0
	loot.boss_drop_chance = 1.0
	loot.regular_coin_amount = 1
	loot.boss_coin_min = 2
	loot.boss_coin_max = 4
	loot.set_seed(12345)
	if loot.roll_drop(LootManager.Source.REGULAR_ENEMY) != 1:
		_fail("Regular enemy guaranteed roll should return one coin.")
	var boss_amount := loot.roll_drop(LootManager.Source.BOSS)
	if boss_amount < 2 or boss_amount > 4:
		_fail("Boss coin amount should stay between two and four.")
	loot.regular_drop_chance = 0.0
	if loot.roll_drop(LootManager.Source.REGULAR_ENEMY) != 0:
		_fail("Zero drop chance should never return coins.")
	loot.free()


func _test_drop_distribution() -> void:
	var loot := LootManager.new()
	loot.set_seed(987654)
	var regular_drops := 0
	for _index in 100000:
		if loot.roll_drop(LootManager.Source.REGULAR_ENEMY) > 0:
			regular_drops += 1
	var regular_rate := float(regular_drops) / 100000.0
	if absf(regular_rate - 0.015) > 0.002:
		_fail("Regular drop rate %.4f is outside the accepted margin." % regular_rate)

	loot.set_seed(456789)
	var boss_drops := 0
	for _index in 100000:
		if loot.roll_drop(LootManager.Source.BOSS) > 0:
			boss_drops += 1
	var boss_rate := float(boss_drops) / 100000.0
	if absf(boss_rate - 0.12) > 0.01:
		_fail("Boss drop rate %.4f is outside the accepted margin." % boss_rate)
	loot.free()


func _test_catalog_validation() -> void:
	var fake := ShopItemData.new()
	fake.id = &"invalid_product"
	fake.category = ShopItemData.Category.WEAPON
	fake.price = 0
	fake.content = load("res://resources/weapons/mjolnir_data.tres")
	if SaveManager.try_purchase(fake):
		_fail("Products outside the catalog must be rejected.")


func _test_save_and_purchases() -> void:
	_remove_test_save()
	var manager := SAVE_MANAGER_SCRIPT.new()
	manager.save_path = TEST_SAVE_PATH
	add_child(manager)
	if manager.get_currency() != 0 or manager.has_unlocked_character("punisher") \
			or manager.has_unlocked_character("arthur") or manager.has_unlocked_character("kratos"):
		_fail("A new save should start with zero coins and all shop characters locked.")
	var punisher := _find_product(ShopItemData.Category.CHARACTER, &"punisher")
	if not punisher:
		_fail("The Punisher product should exist in the catalog.")
		manager.free()
		_remove_test_save()
		return
	var starting_currency: int = punisher.price + 20
	if not manager.add_currency(starting_currency):
		_fail("Positive currency should be accepted.")
	if manager.add_currency(0) or manager.add_currency(-1):
		_fail("Non-positive currency should be rejected.")
	if not manager.try_purchase(punisher):
		_fail("A catalog product should be purchasable with enough currency.")
	if manager.get_currency() != 20:
		_fail("Purchase should deduct the exact product price.")
	if not manager.is_unlocked(&"character", &"punisher") \
			or not manager.is_unlocked(&"weapon", &"punisher_gun") \
			or not manager.is_unlocked(&"weapon", &"punisher_grenade"):
		_fail("Purchasing the Punisher should unlock both exclusive weapons.")
	if manager.try_purchase(punisher) or manager.get_currency() != 20:
		_fail("A purchased product must not be charged twice.")
	var anubis := ShopCatalog.get_products(ShopItemData.Category.WEAPON)[0]
	if manager.try_purchase(anubis) or manager.get_currency() != 20:
		_fail("A purchase without enough currency must not change the save.")
	manager.free()

	var reloaded := SAVE_MANAGER_SCRIPT.new()
	reloaded.save_path = TEST_SAVE_PATH
	add_child(reloaded)
	if reloaded.get_currency() != 20 or not reloaded.has_unlocked_character("punisher"):
		_fail("Currency and unlocks should survive a save reload.")
	reloaded.free()
	_remove_test_save()


func _test_legacy_save_migration() -> void:
	_remove_test_save()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"currency": -5,
		"unlocked_characters": ["eirik", "arthur", "punisher", "punisher"],
		"unlocked_weapons": ["mjolnir", "anubiscurse", "anubiscurse"],
		"custom_safe_field": "preserve",
	}))
	file = null
	var manager := SAVE_MANAGER_SCRIPT.new()
	manager.save_path = TEST_SAVE_PATH
	add_child(manager)
	if manager.get_currency() != 0:
		_fail("Migration should normalize negative currency.")
	if not manager.has_unlocked_character("punisher"):
		_fail("Migration should preserve an unlocked Punisher.")
	if manager.has_unlocked_character("arthur"):
		_fail("Version 4 migration should move Arthur out of the free character roster.")
	if not manager.is_unlocked(&"weapon", &"anubis_curse") \
			or manager.is_unlocked(&"weapon", &"anubiscurse"):
		_fail("Migration should normalize the Anubis Curse ID.")
	if manager.save_data.get("custom_safe_field") != "preserve" \
			or not manager.save_data.has("unlocked_items"):
		_fail("Migration should preserve safe unknown data and add new keys.")
	if manager.get_master_volume() != 0.8 or manager.get_music_volume() != 0.8 \
			or manager.is_fullscreen_enabled():
		_fail("Migration should add safe default settings to legacy saves.")
	manager.free()
	_remove_test_save()


func _test_settings_persistence() -> void:
	_remove_test_save()
	var manager := SAVE_MANAGER_SCRIPT.new()
	manager.save_path = TEST_SAVE_PATH
	manager.apply_runtime_settings = false
	add_child(manager)
	manager.set_master_volume(0.35)
	manager.set_music_volume(0.6)
	manager.set_fullscreen_enabled(true)
	manager.save_data["unlocked_items"] = ["ankh_of_osiris", "horn_of_poetic_mead", "golden_fleece", "vial_of_mimirs_waters"]
	if not manager.equip_item(&"ankh_of_osiris") or not manager.equip_item(&"horn_of_poetic_mead") \
			or not manager.equip_item(&"golden_fleece") or manager.equip_item(&"vial_of_mimirs_waters"):
		_fail("The item loadout should accept exactly three unique unlocked items.")
	manager.free()

	var reloaded := SAVE_MANAGER_SCRIPT.new()
	reloaded.save_path = TEST_SAVE_PATH
	reloaded.apply_runtime_settings = false
	add_child(reloaded)
	if not is_equal_approx(reloaded.get_master_volume(), 0.35) \
			or not is_equal_approx(reloaded.get_music_volume(), 0.6) \
			or not reloaded.is_fullscreen_enabled():
		_fail("Audio and fullscreen settings should survive a save reload.")
	if reloaded.get_equipped_items() != [&"ankh_of_osiris", &"horn_of_poetic_mead", &"golden_fleece"]:
		_fail("The three equipped item slots should survive a save reload.")
	reloaded.free()
	_remove_test_save()


func _remove_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _find_product(category: int, product_id: StringName) -> ShopItemData:
	for product in ShopCatalog.get_products(category):
		if product.id == product_id:
			return product
	return null


func _test_coin_pooling() -> void:
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	var items := Node2D.new()
	items.name = "Items"
	world.add_child(items)
	var loot := LootManager.new()
	loot.regular_drop_chance = 1.0
	add_child(loot)
	loot.handle_defeat(Vector2.ZERO, LootManager.Source.REGULAR_ENEMY)
	var first_coin := items.get_child(0) as CoinPickup
	first_coin.collect()
	await get_tree().process_frame
	loot.handle_defeat(Vector2.ONE, LootManager.Source.REGULAR_ENEMY)
	if loot.get_pool_size() != 1 or items.get_child(0) != first_coin:
		_fail("Collected coins should be reused from the pool.")
	loot.queue_free()
	world.queue_free()


func _test_coin_single_collection() -> void:
	var coin := CoinPickup.new()
	add_child(coin)
	coin.setup(Vector2.ZERO, 3)
	if coin.collect() != 3:
		_fail("Coin should return its configured amount on first collection.")
	if coin.collect() != 0:
		_fail("Coin should return zero after being collected.")


func _fail(message: String) -> void:
	_failures += 1
	push_error("Shop/loot test: %s" % message)
