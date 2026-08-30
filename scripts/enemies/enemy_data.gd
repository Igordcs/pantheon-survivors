extends Resource
class_name EnemyData
## Dados configuráveis de um tipo de inimigo.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_health: float = 30.0
@export var speed: float = 80.0
@export var contact_damage: float = 10.0
@export var score_value: int = 10
@export_range(0.0, 10.0, 0.05) var spawn_weight: float = 1.0

@export_group("Attack")
@export var attack_cooldown: float = 1.0
@export var attack_range: float = 3.0

@export_group("Heal")
@export var heal_interval: float = 3.0
@export var heal_range: float = 200.0
@export var heal_amount: float = 10.0

@export_group("projectile")
@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 300.0
@export_range(0.1, 1.0, 0.05) var projectile_slow_multiplier: float = 1.0
@export var projectile_slow_duration: float = 0.0

@export_group("Special Movement")
@export var charge_damage: float = 0.0
@export var charge_speed: float = 320.0
@export var charge_cooldown: float = 5.0
@export var charge_windup: float = 0.75

@export_group("Visual")
@export_range(16.0, 256.0, 1.0) var visual_size: float = 64.0
@export_dir var sprite_directory: String = ""
@export var sprite_south: Texture2D
@export var sprite_south_east: Texture2D
@export var sprite_east: Texture2D
@export var sprite_north_east: Texture2D
@export var sprite_north: Texture2D
@export var sprite_north_west: Texture2D
@export var sprite_west: Texture2D
@export var sprite_south_west: Texture2D

var _directory_sprites: Dictionary = {}
var _directory_sprites_loaded: bool = false


func get_directional_sprite(direction: Vector2) -> Texture2D:
	var direction_name := DirectionalSpriteHelper.get_direction_name(direction)
	var directional_sprite: Texture2D
	match direction_name:
		&"east":
			directional_sprite = sprite_east
		&"south-east":
			directional_sprite = sprite_south_east
		&"south":
			directional_sprite = sprite_south
		&"south-west":
			directional_sprite = sprite_south_west
		&"west":
			directional_sprite = sprite_west
		&"north-west":
			directional_sprite = sprite_north_west
		&"north":
			directional_sprite = sprite_north
		&"north-east":
			directional_sprite = sprite_north_east

	if directional_sprite:
		return directional_sprite

	_ensure_directory_sprites_loaded()
	directional_sprite = DirectionalSpriteHelper.get_sprite(_directory_sprites, direction)
	return directional_sprite if directional_sprite else sprite_south


func has_visual() -> bool:
	if (
		sprite_south or sprite_south_east or sprite_east or sprite_north_east
		or sprite_north or sprite_north_west or sprite_west or sprite_south_west
	):
		return true

	_ensure_directory_sprites_loaded()
	return not _directory_sprites.is_empty()


func _ensure_directory_sprites_loaded() -> void:
	if _directory_sprites_loaded:
		return
	_directory_sprites_loaded = true
	_directory_sprites = DirectionalSpriteHelper.load_directory(sprite_directory)
