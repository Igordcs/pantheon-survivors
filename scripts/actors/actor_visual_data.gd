extends Resource
class_name ActorVisualData
## Configuração visual compartilhada por personagens, inimigos e bosses.

@export_dir var idle_directory: String = ""
@export_dir var walk_directory: String = ""
@export_dir var attack_directory: String = ""
@export_dir var death_directory: String = ""
@export_range(1.0, 30.0, 0.5) var idle_fps := 6.0
@export_range(1.0, 30.0, 0.5) var walk_fps := 8.0
@export_range(1.0, 30.0, 0.5) var attack_fps := 10.0
@export_range(0.0, 256.0, 1.0) var reference_height := 64.0

var _idle: Dictionary = {}
var _walk: Dictionary = {}
var _loaded := false


func get_idle(direction: Vector2) -> Texture2D:
	_load_once()
	return DirectionalSpriteHelper.get_sprite(_idle, direction)


func get_walk_frames(direction: Vector2) -> Array[Texture2D]:
	_load_once()
	var result: Array[Texture2D] = []
	var stored = _walk.get(DirectionalSpriteHelper.get_direction_name(direction), _walk.get(&"south", []))
	if stored is Array:
		for frame in stored:
			if frame is Texture2D:
				result.append(frame as Texture2D)
	return result


func has_walk() -> bool:
	_load_once()
	return not _walk.is_empty()


func _load_once() -> void:
	if _loaded:
		return
	_loaded = true
	_idle = DirectionalSpriteHelper.load_directory(idle_directory)
	_walk = DirectionalSpriteHelper.load_animation_directory(walk_directory)
