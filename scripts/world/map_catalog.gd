extends RefCounted
class_name MapCatalog
## Every playable map, resolved by id. Mirrors ShopCatalog/ItemCatalog.

const DEFAULT_MAP_ID := &"field"

const MAP_PATHS := [
	"res://resources/maps/field.tres",
	"res://resources/maps/ruins.tres",
	"res://resources/maps/snow.tres",
]

static var MAPS: Array[MapData] = _build_maps()


static func get_maps() -> Array[MapData]:
	return MAPS


static func get_map(map_id: StringName) -> MapData:
	for map in MAPS:
		if map != null and map.map_id == map_id:
			return map
	return get_default_map()


static func get_default_map() -> MapData:
	for map in MAPS:
		if map != null and map.map_id == DEFAULT_MAP_ID:
			return map
	return MAPS[0] if not MAPS.is_empty() else null


static func has_map(map_id: StringName) -> bool:
	for map in MAPS:
		if map != null and map.map_id == map_id:
			return true
	return false


static func _build_maps() -> Array[MapData]:
	var result: Array[MapData] = []
	for path in MAP_PATHS:
		if not ResourceLoader.exists(path):
			push_warning("MapCatalog: mapa ausente em \"%s\"." % path)
			continue
		var map := load(path) as MapData
		if map != null and map.is_valid():
			result.append(map)
		else:
			push_warning("MapCatalog: \"%s\" não é um MapData válido." % path)
	return result
