extends RefCounted
class_name ItemCatalog
## Índice de ItemData persistidos como resources editáveis pelo Inspector.

const FUNDAMENTAL_PATHS: Array[String] = [
	"res://resources/items/fundamentals/chronos_hourglass.tres",
	"res://resources/items/fundamentals/thoths_papyrus.tres",
	"res://resources/items/fundamentals/amphora_of_ambrosia.tres",
	"res://resources/items/fundamentals/aegis_of_athena.tres",
	"res://resources/items/fundamentals/megingjord.tres",
	"res://resources/items/fundamentals/tyches_cornucopia.tres",
	"res://resources/items/fundamentals/hermes_sandals.tres",
]

const SPECIAL_PATHS: Array[String] = [
	"res://resources/items/specials/ankh_of_osiris.tres",
	"res://resources/items/specials/horn_of_poetic_mead.tres",
	"res://resources/items/specials/golden_fleece.tres",
	"res://resources/items/specials/vial_of_mimirs_waters.tres",
	"res://resources/items/specials/feather_of_maat.tres",
	"res://resources/items/specials/ariadnes_thread_ball.tres",
	"res://resources/items/specials/eye_of_horus.tres",
	"res://resources/items/specials/draupnir_ring.tres",
	"res://resources/items/specials/tyet_amulet_of_isis.tres",
	"res://resources/items/specials/odins_sacrificed_eye.tres",
	"res://resources/items/specials/hippolytas_belt.tres",
]

static var _items: Dictionary[StringName, ItemData] = {}

static func get_all() -> Array[ItemData]:
	return _items_for_paths(FUNDAMENTAL_PATHS + SPECIAL_PATHS)

static func get_item(id: StringName) -> ItemData:
	_ensure_loaded()
	return _items.get(id)

static func has_item(id: StringName) -> bool:
	_ensure_loaded()
	return _items.has(id)

static func is_fundamental(id: StringName) -> bool:
	return has_item(id) and _paths_contain_id(FUNDAMENTAL_PATHS, id)

static func is_shop_item(id: StringName) -> bool:
	return has_item(id) and _paths_contain_id(SPECIAL_PATHS, id)

static func get_fundamentals() -> Array[ItemData]:
	return _items_for_paths(FUNDAMENTAL_PATHS)

static func get_shop_items() -> Array[ItemData]:
	return get_specials()

static func get_specials() -> Array[ItemData]:
	return _items_for_paths(SPECIAL_PATHS)

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary[StringName, bool] = {}
	for path in FUNDAMENTAL_PATHS + SPECIAL_PATHS:
		if not ResourceLoader.exists(path):
			errors.append("Item resource ausente: %s" % path)
			continue
		var item := load(path) as ItemData
		var expected_id := _id_for_path(path)
		if not item:
			errors.append("Resource não é ItemData: %s" % path)
		elif item.id != expected_id:
			errors.append("Item '%s' possui ID divergente: %s" % [path, item.id])
		elif seen.has(item.id):
			errors.append("Item possui ID duplicado: %s" % item.id)
		elif not item.icon:
			errors.append("Item '%s' não possui ícone." % item.id)
		else:
			seen[item.id] = true
	return errors

static func _items_for_paths(paths: Array[String]) -> Array[ItemData]:
	_ensure_loaded()
	var result: Array[ItemData] = []
	for path in paths:
		var item := _items.get(_id_for_path(path))
		if item:
			result.append(item)
	return result

static func _ensure_loaded() -> void:
	if not _items.is_empty():
		return
	for path in FUNDAMENTAL_PATHS + SPECIAL_PATHS:
		var item := load(path) as ItemData
		if item and not _items.has(item.id):
			_items[item.id] = item
		else:
			push_error("ItemCatalog: resource inválido ou duplicado em %s" % path)

static func _id_for_path(path: String) -> StringName:
	return StringName(path.get_file().get_basename())

static func _paths_contain_id(paths: Array[String], id: StringName) -> bool:
	for path in paths:
		if _id_for_path(path) == id:
			return true
	return false
