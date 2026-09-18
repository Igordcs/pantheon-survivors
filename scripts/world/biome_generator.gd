class_name BiomeGenerator
extends Node
## Selects continuous biome regions from world-space FastNoiseLite values.
## The biome list comes from the active MapData, so every map defines its own terrain.

@export_category("Noise Fallback")
## Used only until [method configure] receives a MapData.
@export_range(0.0001, 0.02, 0.0001) var noise_frequency: float = 0.0001
@export_range(1, 8, 1) var fractal_octaves: int = 3
@export_range(0.0, 1.0, 0.01) var fractal_gain: float = 0.5
@export_range(0.0, 600.0, 5.0) var border_warp_amplitude: float = 200.0
@export_range(0.0001, 0.05, 0.0001) var border_warp_frequency: float = 0.004

var biomes: Array[BiomeData] = []
var safe_biome_index: int = 0

var _noise := FastNoiseLite.new()


func configure(world_seed: int, map_data: MapData = null) -> void:
	if map_data != null:
		biomes = map_data.get_biomes()
		safe_biome_index = map_data.get_safe_biome_index()
		noise_frequency = map_data.noise_frequency
		fractal_octaves = map_data.fractal_octaves
		fractal_gain = map_data.fractal_gain
		border_warp_amplitude = map_data.border_warp_amplitude
		border_warp_frequency = map_data.border_warp_frequency
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = fractal_octaves
	_noise.fractal_gain = fractal_gain
	# Sem isto a fronteira entre biomas é quase uma reta, e em tiles de 16px vira escada.
	_noise.domain_warp_enabled = border_warp_amplitude > 0.0
	if _noise.domain_warp_enabled:
		_noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
		_noise.domain_warp_amplitude = border_warp_amplitude
		_noise.domain_warp_frequency = border_warp_frequency
		_noise.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_INDEPENDENT
		_noise.domain_warp_fractal_octaves = 2


func get_biome_count() -> int:
	return biomes.size()


## Index of the biome covering this position, matching the map's biome order.
func get_biome_index_at(world_position: Vector2) -> int:
	var noise_value := get_noise_value(world_position)
	for index in range(biomes.size()):
		var biome := biomes[index]
		if noise_value >= biome.min_noise_value and noise_value <= biome.max_noise_value:
			return index
	return safe_biome_index


func get_biome_by_index(index: int) -> BiomeData:
	if index < 0 or index >= biomes.size():
		return get_safe_biome()
	return biomes[index]


func get_biome_at(world_position: Vector2) -> BiomeData:
	return get_biome_by_index(get_biome_index_at(world_position))


func get_safe_biome() -> BiomeData:
	if biomes.is_empty():
		return null
	return biomes[clampi(safe_biome_index, 0, biomes.size() - 1)]


func get_noise_value(world_position: Vector2) -> float:
	return _noise.get_noise_2d(world_position.x, world_position.y)


func get_max_obstacle_density() -> float:
	var result := 0.0
	for biome in biomes:
		if biome != null:
			result = maxf(result, biome.obstacle_density)
	return result
