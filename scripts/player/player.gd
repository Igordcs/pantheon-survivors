extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D;

@export var speed: float = 200.0

var last_direction: Vector2 = Vector2.RIGHT

var _anim_timer: float = 0.0
var _anim_frame: int = 0

var _boss_fight_active: bool = false
var _boss_fight_center: Vector2 = Vector2.ZERO
const BOSS_ARENA_RADIUS: float = 500.0


func _ready() -> void:
	_load_character_data()
	
	var health = $HealthComponent as HealthComponent
	if health:
		health.damaged.connect(_on_damaged)

func _on_damaged(_amount: float, _source_pos: Vector2) -> void:
	ScreenShake.shake(0.6)
	AudioManager.play_sfx("player_hit")


func enter_boss_fight(boss_pos: Vector2) -> void:
	_boss_fight_active = true
	_boss_fight_center = boss_pos

func exit_boss_fight() -> void:
	_boss_fight_active = false


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
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
		
	# Flip sprite based on horizontal movement
	if input_dir.x != 0.0:
		animated_sprite.flip_h = input_dir.x < 0.0
		
	_animate(delta)


func _animate(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer > 0.1: # 10 FPS
		_anim_timer = 0.0
		_anim_frame += 1
		
		if velocity == Vector2.ZERO:
			animated_sprite.play("IDLE");
		else:
			animated_sprite.play("RUN");


func _load_character_data() -> void:
	# Carrega o ID do Global
	var char_id = Global.selected_character_id
	var data_path = "res://resources/characters/%s_data.tres" % char_id
	
	if ResourceLoader.exists(data_path):
		var char_data = load(data_path) as CharacterData
		if char_data:
			# Aplica os status base
			var health_comp = $HealthComponent as HealthComponent
			health_comp.max_health = char_data.base_health
			health_comp.reset()
			
			speed = char_data.base_speed
			
			# Instancia a arma inicial
			if char_data.starting_weapon:
				_instantiate_weapon(char_data.starting_weapon.id)
	else:
		print("ERROR: Character data not found for id: ", char_id)


func _instantiate_weapon(weapon_id: StringName) -> void:
	var weapon_scene_path = "res://scenes/weapons/%s.tscn" % weapon_id
	if ResourceLoader.exists(weapon_scene_path):
		var weapon_scene = load(weapon_scene_path) as PackedScene
		var weapon_inst = weapon_scene.instantiate()
		$WeaponHolder.add_child(weapon_inst)
