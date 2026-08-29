extends Resource
class_name CharacterData
## Dados de um personagem desbloqueável/selecionável.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var portrait: Texture2D
@export var gameplay_sprite: Texture2D
@export_dir var gameplay_sprite_directory: String = ""
@export var starting_weapon: WeaponData
@export var base_health: float = 100.0
@export var base_speed: float = 200.0
@export var passive_description: String = ""

var _directional_sprites: Dictionary = {}
var _directional_sprites_loaded: bool = false


func get_gameplay_sprite(direction: Vector2) -> Texture2D:
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


func _ensure_directional_sprites_loaded() -> void:
	if _directional_sprites_loaded:
		return
	_directional_sprites_loaded = true
	_directional_sprites = DirectionalSpriteHelper.load_directory(gameplay_sprite_directory)
