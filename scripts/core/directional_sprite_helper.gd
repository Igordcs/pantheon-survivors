extends RefCounted
class_name DirectionalSpriteHelper
## Carrega e seleciona sprites organizados em oito direções.

const DIRECTION_NAMES: Array[StringName] = [
	&"east",
	&"south-east",
	&"south",
	&"south-west",
	&"west",
	&"north-west",
	&"north",
	&"north-east",
]


static func load_directory(directory_path: String) -> Dictionary:
	var sprites: Dictionary = {}
	if directory_path.is_empty():
		return sprites

	var normalized_path := directory_path.trim_suffix("/")
	for direction_name in DIRECTION_NAMES:
		var texture_path := "%s/%s.png" % [normalized_path, direction_name]
		if not ResourceLoader.exists(texture_path):
			continue

		var texture := load(texture_path) as Texture2D
		if texture:
			sprites[direction_name] = texture

	return sprites


static func get_direction_name(direction: Vector2) -> StringName:
	if direction.is_zero_approx():
		return &"south"

	# Godot usa Y positivo para baixo: E, SE, S, SO, O, NO, N, NE.
	var octant := posmod(int(round(direction.angle() / (PI / 4.0))), 8)
	return DIRECTION_NAMES[octant]


static func get_sprite(sprites: Dictionary, direction: Vector2) -> Texture2D:
	var texture := sprites.get(get_direction_name(direction)) as Texture2D
	if texture:
		return texture

	texture = sprites.get(&"south") as Texture2D
	if texture:
		return texture

	if not sprites.is_empty():
		return sprites.values()[0] as Texture2D
	return null
