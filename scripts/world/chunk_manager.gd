class_name ChunkManager
extends Node
## Tracks the player and requests the active square of streamed chunks.

signal chunk_required(chunk_coordinate: Vector2i)
signal chunk_released(chunk_coordinate: Vector2i)
signal current_chunk_changed(chunk_coordinate: Vector2i)

@export_category("Streaming")
@export_range(256, 4096, 128) var chunk_size: int = 1024
@export_range(1, 4, 1) var render_distance: int = 1
@export_range(0.05, 1.0, 0.05) var update_interval: float = 0.2
@export_range(9, 256, 1) var max_cached_chunks: int = 64

var current_chunk := Vector2i.ZERO
var _player: Node2D
var _active_coordinates: Dictionary = {}
var _elapsed_time: float = 0.0


func _ready() -> void:
	set_process(false)


func setup(player: Node2D) -> void:
	_player = player
	set_process(is_instance_valid(_player))
	if is_instance_valid(_player):
		refresh_around(_player.global_position, true)


func initialize_at(world_position: Vector2) -> void:
	refresh_around(world_position, true)


func reset_tracking() -> void:
	_active_coordinates.clear()
	_elapsed_time = 0.0


func refresh_around(world_position: Vector2, force: bool = false) -> void:
	var next_chunk := get_chunk_coordinate(world_position)
	if not force and next_chunk == current_chunk:
		return

	var desired_coordinates: Dictionary = {}
	for offset_x in range(-render_distance, render_distance + 1):
		for offset_y in range(-render_distance, render_distance + 1):
			var coordinate := next_chunk + Vector2i(offset_x, offset_y)
			desired_coordinates[coordinate] = true

	# New chunks are available before old ones leave, avoiding visible gaps.
	for coordinate: Vector2i in desired_coordinates:
		if not _active_coordinates.has(coordinate):
			chunk_required.emit(coordinate)
	for coordinate: Vector2i in _active_coordinates:
		if not desired_coordinates.has(coordinate):
			chunk_released.emit(coordinate)

	_active_coordinates = desired_coordinates
	var changed := next_chunk != current_chunk or force
	current_chunk = next_chunk
	if changed:
		current_chunk_changed.emit(current_chunk)


func get_chunk_coordinate(world_position: Vector2) -> Vector2i:
	var half_chunk := chunk_size * 0.5
	return Vector2i(
		floori((world_position.x + half_chunk) / float(chunk_size)),
		floori((world_position.y + half_chunk) / float(chunk_size))
	)


func get_chunk_origin(chunk_coordinate: Vector2i) -> Vector2:
	return Vector2(chunk_coordinate * chunk_size) - Vector2.ONE * chunk_size * 0.5


func get_chunk_bounds(chunk_coordinate: Vector2i) -> Rect2:
	return Rect2(get_chunk_origin(chunk_coordinate), Vector2.ONE * chunk_size)


func get_chunk_seed(world_seed: int, chunk_coordinate: Vector2i) -> int:
	return world_seed ^ (chunk_coordinate.x * 73_856_093) ^ (chunk_coordinate.y * 19_349_663)


func get_active_coordinates() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coordinate: Vector2i in _active_coordinates:
		result.append(coordinate)
	return result


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		set_process(false)
		return
	_elapsed_time += delta
	if _elapsed_time < update_interval:
		return
	_elapsed_time = 0.0
	refresh_around(_player.global_position)
