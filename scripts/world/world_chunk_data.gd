class_name WorldChunkData
extends RefCounted
## Compact cached result of deterministic chunk generation.

var coordinate: Vector2i
var biome_types := PackedByteArray()
var decoration_cells := PackedInt32Array()
var obstacle_blueprints: Array[Dictionary] = []


func _init(chunk_coordinate: Vector2i = Vector2i.ZERO) -> void:
	coordinate = chunk_coordinate
