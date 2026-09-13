extends CharacterBody2D

@export var speed: float = 170.0
@export_range(32.0, 192.0, 1.0) var character_visual_height: float = 80.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent

var last_direction: Vector2 = Vector2.DOWN
var _character_data: CharacterData
var _uses_directional_sprites: bool = false
var _world_generator: WorldGenerator
var _temporary_slow_multiplier: float = 1.0
var _temporary_slow_timer: float = 0.0

var _boss_fight_active: bool = false
var _boss_fight_center: Vector2 = Vector2.ZERO
const BOSS_ARENA_RADIUS: float = 500.0


func _ready() -> void:
	_load_character_data()

	if health_component:
		health_component.damaged.connect(_on_damaged)

func _on_damaged(_amount: float, _source_pos: Vector2) -> void:
	AudioManager.play_sfx("player_hit")


func _physics_process(delta: float) -> void:
	_temporary_slow_timer = maxf(_temporary_slow_timer - delta, 0.0)
	if _temporary_slow_timer <= 0.0:
		_temporary_slow_multiplier = 1.0
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var terrain_speed_multiplier := 1.0
	if is_instance_valid(_world_generator):
		terrain_speed_multiplier = _world_generator.get_movement_speed_multiplier_at(global_position)
	velocity = input_dir * speed * terrain_speed_multiplier * _temporary_slow_multiplier
	move_and_slide()
	
	# Boss fight boundary: clamp position to camera view (1280x720 with 1.6 zoom)
	if _boss_fight_active:
		var half_w = (1280.0 / 1.4 / 2.0)
		var half_h = (720.0 / 1.4 / 2.0)
		var min_x = _boss_fight_center.x - half_w
		var max_x = _boss_fight_center.x + half_w
		var min_y = _boss_fight_center.y - half_h
		var max_y = _boss_fight_center.y + half_h
		
		global_position.x = clamp(global_position.x, min_x, max_x)
		global_position.y = clamp(global_position.y, min_y, max_y)

	# Update facing direction
	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()
	_update_character_animation(last_direction, input_dir != Vector2.ZERO)


func setup_world_generator(world_generator: WorldGenerator) -> void:
	_world_generator = world_generator


func apply_temporary_slow(multiplier: float, duration: float) -> void:
	_temporary_slow_multiplier = minf(_temporary_slow_multiplier, clampf(multiplier, 0.1, 1.0))
	_temporary_slow_timer = maxf(_temporary_slow_timer, duration)


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
			
			# Punisher: instancia a granada junto com a arma base
			if char_id == "punisher":
				_instantiate_weapon(&"punisher_grenade")

			return

	push_error("Character data not found or invalid for id: %s" % char_id)


func debug_switch_character(character_id: StringName) -> void:
	Global.selected_character_id = character_id
	for weapon in $WeaponHolder.get_children():
		weapon.free()
	_load_character_data()


func _apply_character_visual(char_data: CharacterData) -> void:
	_character_data = char_data
	_uses_directional_sprites = char_data.has_directional_gameplay_sprites()
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.remove_animation(&"default")
	_update_character_animation(Vector2.DOWN, false)


func _update_character_animation(direction: Vector2, is_moving: bool) -> void:
	if not _character_data:
		return

	var direction_name := DirectionalSpriteHelper.get_direction_name(direction)
	var state_name := "walk" if is_moving and _character_data.has_walk_animation() else "idle"
	var animation_name := StringName("%s_%s" % [state_name, direction_name])
	_ensure_character_animation(animation_name, direction, state_name == "walk")
	if not sprite.sprite_frames.has_animation(animation_name):
		sprite.visible = false
		push_warning("Character has no gameplay sprite: %s" % _character_data.id)
		return

	sprite.visible = true
	sprite.flip_h = false if _uses_directional_sprites else direction.x < 0.0
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)
	var character_texture := sprite.sprite_frames.get_frame_texture(animation_name, 0)
	if character_texture:
		_apply_character_visual_size(character_texture)


func _ensure_character_animation(
	animation_name: StringName,
	direction: Vector2,
	is_walk: bool
) -> void:
	if sprite.sprite_frames.has_animation(animation_name):
		return

	var textures: Array[Texture2D] = []
	if is_walk:
		textures = _character_data.get_walk_frames(direction)
	else:
		var idle_texture := _character_data.get_gameplay_sprite(direction)
		if idle_texture:
			textures.append(idle_texture)
	if textures.is_empty():
		return

	sprite.sprite_frames.add_animation(animation_name)
	sprite.sprite_frames.set_animation_loop(animation_name, true)
	sprite.sprite_frames.set_animation_speed(
		animation_name,
		_character_data.walk_animation_speed if is_walk else 1.0
	)
	for texture in textures:
		sprite.sprite_frames.add_frame(animation_name, texture)


func _apply_character_visual_size(character_texture: Texture2D) -> void:
	var texture_height := _character_data.gameplay_reference_height \
		if _character_data and _character_data.gameplay_reference_height > 0.0 \
		else float(character_texture.get_height())
	if texture_height > 0.0:
		var scale_factor := character_visual_height / texture_height
		sprite.scale = Vector2.ONE * scale_factor


func _instantiate_weapon(weapon_id: StringName) -> void:
	var weapon_scene_path = "res://scenes/weapons/%s.tscn" % weapon_id
	if ResourceLoader.exists(weapon_scene_path):
		var weapon_scene = load(weapon_scene_path) as PackedScene
		var weapon_inst = weapon_scene.instantiate()
		$WeaponHolder.add_child(weapon_inst)
