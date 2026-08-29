extends CharacterBody2D
## Player — movimento em 8 direções com WASD/setas.

@export var speed: float = 200.0
@export_range(32.0, 192.0, 1.0) var character_visual_height: float = 80.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent

var last_direction: Vector2 = Vector2.RIGHT
var _character_data: CharacterData
var _uses_directional_sprites: bool = false


func _ready() -> void:
	_load_character_data()

	if health_component:
		health_component.damaged.connect(_on_damaged)

func _on_damaged(_amount: float, _source_pos: Vector2) -> void:
	ScreenShake.shake(0.6)
	AudioManager.play_sfx("player_hit")


func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
	move_and_slide()

	# Update facing direction
	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()
		_update_character_direction(last_direction)


func _load_character_data() -> void:
	# Carrega o ID do Global
	var char_id = Global.selected_character_id
	var data_path = "res://resources/characters/%s_data.tres" % char_id
	
	if ResourceLoader.exists(data_path):
		var char_data = load(data_path) as CharacterData
		if char_data:
			_apply_character_visual(char_data)

			# Aplica os status base
			health_component.max_health = char_data.base_health
			health_component.reset()
			
			speed = char_data.base_speed
			
			# Instancia a arma inicial
			if char_data.starting_weapon:
				_instantiate_weapon(char_data.starting_weapon.id)
			return

	push_error("Character data not found or invalid for id: %s" % char_id)


func _apply_character_visual(char_data: CharacterData) -> void:
	_character_data = char_data
	_uses_directional_sprites = char_data.has_directional_gameplay_sprites()
	_update_character_direction(Vector2.DOWN)


func _update_character_direction(direction: Vector2) -> void:
	if not _character_data:
		return

	var character_texture := _character_data.get_gameplay_sprite(direction)
	if not character_texture:
		sprite.visible = false
		push_warning("Character has no gameplay sprite: %s" % _character_data.id)
		return

	if sprite.texture != character_texture:
		sprite.texture = character_texture
		_apply_character_visual_size(character_texture)

	sprite.hframes = 1
	sprite.vframes = 1
	sprite.frame = 0
	sprite.visible = true
	sprite.flip_h = false if _uses_directional_sprites else direction.x < 0.0


func _apply_character_visual_size(character_texture: Texture2D) -> void:
	var texture_height := float(character_texture.get_height())
	if texture_height > 0.0:
		var scale_factor := character_visual_height / texture_height
		sprite.scale = Vector2.ONE * scale_factor


func _instantiate_weapon(weapon_id: StringName) -> void:
	var weapon_scene_path = "res://scenes/weapons/%s.tscn" % weapon_id
	if ResourceLoader.exists(weapon_scene_path):
		var weapon_scene = load(weapon_scene_path) as PackedScene
		var weapon_inst = weapon_scene.instantiate()
		$WeaponHolder.add_child(weapon_inst)
