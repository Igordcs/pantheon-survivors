extends Area2D

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/anubis_curse.tres")

var _tick_timer: Timer
var _current_level: int = 1
var _damage: float = 5.0
var _radius: float = 100.0
var _knockback_force: float = 0.0

var _enemies_in_range: Array[CharacterBody2D] = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2

	if not collision_shape:
		var shape := CircleShape2D.new()
		shape.radius = _radius
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		collision.shape = shape
		add_child(collision)
		collision_shape = collision

	if not sprite:
		var sprite_node := Sprite2D.new()
		sprite_node.name = "Sprite2D"
		sprite_node.texture = load("res://assets/sprites/weapons/AnubisCurse.png")
		sprite_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		add_child(sprite_node)
		sprite = sprite_node

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_tick_timer = Timer.new()
	_tick_timer.one_shot = false
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_on_tick_timeout)
	add_child(_tick_timer)
	
	_apply_level_stats()

func _process(delta: float) -> void:
	if sprite:
		sprite.rotation += 1.5 * delta

func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"anubis_curse"

func get_current_level() -> int:
	return _current_level

func get_next_upgrade_description() -> String:
	if not weapon_data or _current_level >= weapon_data.max_level:
		return "Nível máximo."
	return weapon_data.get_level_description(_current_level + 1)

func upgrade() -> void:
	if not weapon_data or _current_level >= weapon_data.max_level:
		return
	_current_level += 1
	_apply_level_stats()
	weapon_upgraded.emit(get_weapon_id(), _current_level)

func _apply_level_stats() -> void:
	if not weapon_data:
		return
	var level_data := weapon_data.get_level_data(_current_level)
	if not level_data:
		return

	_damage = weapon_data.base_damage * level_data.damage_multiplier
	_radius = weapon_data.area * level_data.area_multiplier
	_knockback_force = level_data.special_value

	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = _radius

	if sprite:
		var scale_factor = _radius / 100.0
		sprite.scale = Vector2(scale_factor, scale_factor)

	if _tick_timer:
		_tick_timer.wait_time = maxf(0.1, weapon_data.cooldown * level_data.cooldown_multiplier)

func _on_body_entered(body: Node2D) -> void:
	var enemy := body as CharacterBody2D
	if enemy and enemy.is_in_group("enemies"):
		if not _enemies_in_range.has(enemy):
			_enemies_in_range.append(enemy)
			_apply_damage(enemy)

func _on_body_exited(body: Node2D) -> void:
	var enemy := body as CharacterBody2D
	if _enemies_in_range.has(enemy):
		_enemies_in_range.erase(enemy)

func _on_tick_timeout() -> void:
	_enemies_in_range = _enemies_in_range.filter(func(e): return is_instance_valid(e) and e.visible)
	
	for enemy in _enemies_in_range:
		_apply_damage(enemy)

func _apply_damage(enemy: CharacterBody2D) -> void:
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(_damage, global_position)
		if _knockback_force > 0.0 and enemy.has_method("apply_knockback"):
			var dir := global_position.direction_to(enemy.global_position)
			enemy.apply_knockback(dir * _knockback_force)
