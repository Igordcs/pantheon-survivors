extends Area2D
## Aura Sagrada — causa dano periódico a inimigos dentro da área.

@export var weapon_data: WeaponData = preload("res://resources/weapons/holy_aura_data.tres")

var _tick_timer: Timer
var _current_level: int = 1
var _shape: CircleShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detecta inimigos
	
	_shape = CircleShape2D.new()
	_shape.radius = weapon_data.area if weapon_data else 100.0
	
	var col := CollisionShape2D.new()
	col.shape = _shape
	add_child(col)
	
	_tick_timer = Timer.new()
	_tick_timer.wait_time = weapon_data.cooldown if weapon_data else 1.0
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"holy_aura"


func get_current_level() -> int:
	return _current_level


func upgrade() -> void:
	if weapon_data and _current_level < weapon_data.max_level:
		_current_level += 1
		# Aumenta a área em 10% por nível
		_shape.radius = weapon_data.area * (1.0 + (_current_level - 1) * 0.1)


func _on_tick() -> void:
	var base_dmg := weapon_data.base_damage if weapon_data else 5.0
	# Aumenta dano em 20% por nível
	var dmg := base_dmg * (1.0 + (_current_level - 1) * 0.2)
	
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if not body.is_in_group("enemies"):
			continue
		var health := body.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(dmg)
			_hit_flash(body)


func _hit_flash(body: Node2D) -> void:
	var sprite := body.get_node_or_null("Sprite2D") as CanvasItem
	if not sprite:
		return
	var tween := body.create_tween()
	sprite.modulate = Color.WHITE
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.15)
