extends Resource
class_name CharacterData
## Dados de um personagem desbloqueável/selecionável.

const ActorVisualDataType := preload("res://scripts/actors/actor_visual_data.gd")

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var portrait: Texture2D
@export var gameplay_sprite: Texture2D
@export var visual: ActorVisualDataType
@export_dir var gameplay_sprite_directory: String = ""
@export_dir var walk_sprite_directory: String = ""
@export_range(1.0, 30.0, 0.5) var walk_animation_speed: float = 8.0
@export_range(0.0, 256.0, 1.0) var gameplay_reference_height: float = 0.0
@export var starting_weapon: WeaponData
@export var base_health: float = 100.0
@export var base_speed: float = 170.0
@export var passive_description: String = ""

var _directional_sprites: Dictionary = {}
var _directional_sprites_loaded: bool = false
var _walk_sprites: Dictionary = {}
var _walk_sprites_loaded: bool = false


func get_gameplay_sprite(direction: Vector2) -> Texture2D:
	if visual:
		var configured := visual.get_idle(direction)
		if configured:
			return configured
	_ensure_directional_sprites_loaded()
	var directional_sprite := DirectionalSpriteHelper.get_sprite(_directional_sprites, direction)
	if directional_sprite:
		return directional_sprite
	if gameplay_sprite:
		return gameplay_sprite
	return portrait


func has_directional_gameplay_sprites() -> bool:
	_ensure_directional_sprites_loaded()
	return not _directional_sprites.is_empty()


func get_walk_frames(direction: Vector2) -> Array[Texture2D]:
	if visual:
		var configured := visual.get_walk_frames(direction)
		if not configured.is_empty():
			return configured
	_ensure_walk_sprites_loaded()
	var direction_name := DirectionalSpriteHelper.get_direction_name(direction)
	var frames: Array[Texture2D] = []
	var stored_frames = _walk_sprites.get(direction_name)
	if stored_frames is Array:
		for frame in stored_frames:
			if frame is Texture2D:
				frames.append(frame as Texture2D)
	if not frames.is_empty():
		return frames

	stored_frames = _walk_sprites.get(&"south")
	if stored_frames is Array:
		for frame in stored_frames:
			if frame is Texture2D:
				frames.append(frame as Texture2D)
	return frames


func has_walk_animation() -> bool:
	if visual and visual.has_walk():
		return true
	_ensure_walk_sprites_loaded()
	return not _walk_sprites.is_empty()


func _ensure_directional_sprites_loaded() -> void:
	if _directional_sprites_loaded:
		return
	_directional_sprites_loaded = true
	_directional_sprites = DirectionalSpriteHelper.load_directory(gameplay_sprite_directory)


func _ensure_walk_sprites_loaded() -> void:
	if _walk_sprites_loaded:
		return
	_walk_sprites_loaded = true
	_walk_sprites = DirectionalSpriteHelper.load_animation_directory(walk_sprite_directory)
