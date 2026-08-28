extends Node2D
## Excalibur — arma melee direcional que ataca na última direção do player.

@export var weapon_data: WeaponData = preload("res://resources/weapons/excalibur_data.tres")

var _cooldown_timer: Timer
var _current_level: int = 1
var _hitbox: Area2D
var _sprite: Sprite2D


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.wait_time = weapon_data.cooldown if weapon_data else 1.5
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)
	
	_hitbox = get_node("Hitbox")
	_sprite = get_node("Hitbox/Sprite2D")
	_hitbox.monitoring = false
	_hitbox.visible = false
	_hitbox.body_entered.connect(_on_body_entered)


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"excalibur"


func get_current_level() -> int:
	return _current_level


func upgrade() -> void:
	if weapon_data and _current_level < weapon_data.max_level:
		_current_level += 1
		_cooldown_timer.wait_time = maxf(0.5, weapon_data.cooldown - ((_current_level - 1) * 0.1))
		var scale_mult := 1.0 + ((_current_level - 1) * 0.15)
		_hitbox.scale = Vector2(scale_mult, scale_mult)


func _on_cooldown_timeout() -> void:
	var player = get_parent().get_parent() # Player -> WeaponHolder -> Excalibur
	var dir = Vector2.RIGHT
	if player and "last_direction" in player:
		dir = player.last_direction
		
	# Aponta o ataque para a direção
	_hitbox.rotation = dir.angle()
	
	# Animação de ataque (swing)
	_hitbox.monitoring = true
	_hitbox.visible = true
	
	var tween = create_tween()
	# Gira 90 graus (da esquerda pra direita do arco)
	_hitbox.rotation_degrees -= 45
	tween.tween_property(_hitbox, "rotation_degrees", _hitbox.rotation_degrees + 90, 0.2)
	tween.tween_callback(func():
		_hitbox.monitoring = false
		_hitbox.visible = false
	)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return
	
	var base_dmg := weapon_data.base_damage if weapon_data else 30.0
	var final_dmg := base_dmg * (1.0 + (_current_level - 1) * 0.25)
	
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health and health.is_alive():
		health.take_damage(final_dmg)
		_hit_flash(body)


func _hit_flash(body: Node2D) -> void:
	var sprite := body.get_node_or_null("Sprite2D") as CanvasItem
	if not sprite:
		return
	var tween := body.create_tween()
	sprite.modulate = Color.WHITE
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.15)
