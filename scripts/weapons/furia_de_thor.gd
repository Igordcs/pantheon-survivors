extends Node2D
## Fúria de Thor — Evolução do Mjolnir.
## Cai um relâmpago divino instantâneo no inimigo mais próximo, causando grande dano em área.

@export var weapon_data: WeaponData = preload("res://resources/weapons/furia_de_thor_data.tres")

var _cooldown_timer: Timer
var _current_level: int = 1


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.wait_time = weapon_data.cooldown if weapon_data else 2.0
	_cooldown_timer.one_shot = false
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)
	_cooldown_timer.start()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"furia_de_thor"


func get_current_level() -> int:
	return _current_level


func upgrade() -> void:
	pass # Armas evoluídas não têm upgrades numéricos simples


func _on_cooldown_timeout() -> void:
	var target := _find_closest_enemy()
	if target == null:
		return
	_smite(target.global_position)


func _smite(pos: Vector2) -> void:
	# Efeito visual de raio
	_spawn_lightning_vfx(pos)
	
	# Dano em área
	var area_radius := weapon_data.area if weapon_data else 150.0
	var dmg := weapon_data.base_damage if weapon_data else 100.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		var enemy_body = enemy as CharacterBody2D
		if not is_instance_valid(enemy_body) or not enemy_body.visible:
			continue
			
		var dist_sq = pos.distance_squared_to(enemy_body.global_position)
		if dist_sq <= (area_radius * area_radius):
			var health = enemy_body.get_node_or_null("HealthComponent") as HealthComponent
			if health and health.is_alive():
				health.take_damage(dmg)
				_hit_flash(enemy_body)


func _spawn_lightning_vfx(pos: Vector2) -> void:
	# Cria uma linha temporária para simular um clarão
	var line = Line2D.new()
	line.default_color = Color.CYAN
	line.width = 40.0
	line.add_point(pos - Vector2(0, 1000))
	line.add_point(pos)
	get_tree().current_scene.add_child(line)
	
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): line.queue_free())


func _find_closest_enemy() -> CharacterBody2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: CharacterBody2D = null
	var closest_dist_sq := INF

	for enemy in enemies:
		var enemy_body := enemy as CharacterBody2D
		if not is_instance_valid(enemy_body) or not enemy_body.visible:
			continue
		var health := enemy_body.get_node_or_null("HealthComponent") as HealthComponent
		if health and not health.is_alive():
			continue
		var dist_sq := global_position.distance_squared_to(enemy_body.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = enemy_body

	return closest


func _hit_flash(body: Node2D) -> void:
	var sprite := body.get_node_or_null("Sprite2D") as CanvasItem
	if not sprite:
		return
	var tween := body.create_tween()
	sprite.modulate = Color.WHITE
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3, 1), 0.15)
