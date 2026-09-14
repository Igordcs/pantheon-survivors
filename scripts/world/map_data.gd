class_name MapData
extends Resource
## Data-driven definition of one playable map: its tileset, its biomes and the
## noise shape that distributes them. Adding a map means adding one of these.

@export var map_id: StringName = &"field"
@export var display_name: String = "Campos da Ruptura"

@export_category("Terrain")
@export var tile_set: TileSet
## Biomes are matched in order against the noise value, so the first entry whose
## [member BiomeData.min_noise_value]..[member BiomeData.max_noise_value] range
## contains the value wins. Together they should cover -1.0 to 1.0.
@export var biomes: Array[BiomeData] = []
## Biome used inside the initial safe area, where the player always spawns.
@export var safe_biome_index: int = 0

@export_category("Noise")
@export_range(0.0001, 0.02, 0.0001) var noise_frequency: float = 0.0001
@export_range(1, 8, 1) var fractal_octaves: int = 3
@export_range(0.0, 1.0, 0.01) var fractal_gain: float = 0.5


func get_biomes() -> Array[BiomeData]:
	var result: Array[BiomeData] = []
	for biome in biomes:
		if biome != null:
			result.append(biome)
	return result


func get_safe_biome_index() -> int:
	return clampi(safe_biome_index, 0, maxi(get_biomes().size() - 1, 0))


func is_valid() -> bool:
	return tile_set != null and not get_biomes().is_empty()
