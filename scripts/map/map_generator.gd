extends Node2D
## Gerador de Mapa Procedural Infinito baseado em Chunks e Noise

@export var tile_set: TileSet
@export var tile_size: int = 64
@export var chunk_size: int = 32
@export var render_distance: int = 1 # Raio de chunks ao redor do player (1 = 3x3 chunks)
@export var noise_frequency: float = 0.05

# Configuração de terrenos baseados no valor do noise.
# O threshold é o valor mínimo de noise (de -1 a 1) para aquele terreno ser escolhido.
@export var terrain_configs: Array[Dictionary] = [
	{"source_id": 0, "atlas_coords": Vector2i(0, 0), "threshold": -1.0}, # Base/Grama
	{"source_id": 0, "atlas_coords": Vector2i(1, 0), "threshold": 0.2},  # Terra / Detalhes
	{"source_id": 0, "atlas_coords": Vector2i(0, 1), "threshold": 0.6}   # Outro detalhe
]

var _active_chunks: Dictionary = {} # Vector2i : TileMap
var _noise: FastNoiseLite
var _player: Node2D


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = randi() # Seed aleatória a cada run
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = noise_frequency


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return
			
	var player_pos = _player.global_position
	var current_chunk = _get_chunk_coord(player_pos)
	
	_update_chunks(current_chunk)


func _get_chunk_coord(pos: Vector2) -> Vector2i:
	var chunk_pixel_size = float(chunk_size * tile_size)
	var cx = floor(pos.x / chunk_pixel_size)
	var cy = floor(pos.y / chunk_pixel_size)
	return Vector2i(int(cx), int(cy))


func _update_chunks(center_chunk: Vector2i) -> void:
	var needed_chunks = []
	
	# Calcula todos os chunks no raio de visão
	for x in range(-render_distance, render_distance + 1):
		for y in range(-render_distance, render_distance + 1):
			needed_chunks.append(Vector2i(center_chunk.x + x, center_chunk.y + y))
			
	# Identifica chunks muito distantes para remover
	var chunks_to_remove = []
	for chunk_coord in _active_chunks.keys():
		if not chunk_coord in needed_chunks:
			chunks_to_remove.append(chunk_coord)
			
	# Despawna chunks antigos
	for chunk_coord in chunks_to_remove:
		var chunk_node = _active_chunks[chunk_coord]
		if is_instance_valid(chunk_node):
			chunk_node.queue_free()
		_active_chunks.erase(chunk_coord)
		
	# Instancia e gera chunks novos
	for chunk_coord in needed_chunks:
		if not _active_chunks.has(chunk_coord):
			_generate_chunk(chunk_coord)


func _generate_chunk(chunk_coord: Vector2i) -> void:
	var tm = TileMap.new()
	tm.tile_set = tile_set
	
	var chunk_pixel_size = chunk_size * tile_size
	tm.position = Vector2(chunk_coord.x * chunk_pixel_size, chunk_coord.y * chunk_pixel_size)
	
	add_child(tm)
	_active_chunks[chunk_coord] = tm
	
	var global_tile_offset_x = chunk_coord.x * chunk_size
	var global_tile_offset_y = chunk_coord.y * chunk_size
	
	# Preenche as células
	for x in range(chunk_size):
		for y in range(chunk_size):
			var g_x = global_tile_offset_x + x
			var g_y = global_tile_offset_y + y
			
			var noise_val = _noise.get_noise_2d(g_x, g_y)
			
			var chosen_source = 0
			var chosen_atlas = Vector2i(0, 0)
			
			# Sobrescreve conforme as faixas de noise (a última que bater ganha)
			for config in terrain_configs:
				if noise_val >= config.get("threshold", -1.0):
					chosen_source = config.get("source_id", 0)
					chosen_atlas = config.get("atlas_coords", Vector2i(0, 0))
			
			tm.set_cell(0, Vector2i(x, y), chosen_source, chosen_atlas)


func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null
