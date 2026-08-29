extends CharacterBody2D
## HealerEnemy — Persegue aliados feridos e os cura. Não cura bosses.

@export var enemy_data: EnemyData

var _player: CharacterBody2D
var _contact_cooldown: float = 0.0
const CONTACT_COOLDOWN_TIME: float = 0.5
var _knockback_velocity: Vector2 = Vector2.ZERO
var _heal_timer: float = 0.0


func _ready() -> void:
	_player = _find_player()
	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		if enemy_data:
			health.max_health = enemy_data.max_health
		health.reset()
		health.damaged.connect(_on_damaged)
	
	_heal_timer = enemy_data.heal_interval if enemy_data else 3.0


func _on_damaged(_amount: float, source_pos: Vector2) -> void:
	var tween = create_tween()
	$AnimatedSprite2D.modulate = Color.WHITE
	tween.tween_property($AnimatedSprite2D, "modulate", Color(0.3, 1.0, 0.3, 1), 0.15)
	
	if source_pos != Vector2.ZERO:
		var dir = source_pos.direction_to(global_position)
		_knockback_velocity = dir * 200.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if not is_instance_valid(_player):
			return

	var wounded_ally = _find_wounded_ally()
	var spd := enemy_data.speed if enemy_data else 70.0
	
	if wounded_ally:
		# Persegue o aliado ferido
		var direction = global_position.direction_to(wounded_ally.global_position)
		velocity = direction * spd
		if direction.x != 0.0:
			$AnimatedSprite2D.flip_h = direction.x < 0.0
		$AnimatedSprite2D.play("RUN")
	else:
		# Se não há ferido, segue o player lentamente
		var direction = global_position.direction_to(_player.global_position)
		velocity = direction * spd * 0.5
		if direction.x != 0.0:
			$AnimatedSprite2D.flip_h = direction.x < 0.0
		$AnimatedSprite2D.play("IDLE")
	
	_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
	velocity += _knockback_velocity
	move_and_slide()
	
	# Curar aliados próximos
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_try_heal()
		_heal_timer = enemy_data.heal_interval if enemy_data else 3.0
	
	# Dano de contato (básico)
	_contact_cooldown -= delta
	if _contact_cooldown <= 0.0:
		var distance := global_position.distance_to(_player.global_position)
		if distance < 30.0:
			var player_health := _player.get_node_or_null("HealthComponent") as HealthComponent
			if player_health and player_health.is_alive():
				var dmg := enemy_data.contact_damage if enemy_data else 5.0
				player_health.take_damage(dmg)
				_contact_cooldown = CONTACT_COOLDOWN_TIME


func _try_heal() -> void:
	var heal_range_val = enemy_data.heal_range if enemy_data else 200.0
	var heal_amt = enemy_data.heal_amount if enemy_data else 10.0
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy == self:
			continue
		# Não cura bosses
		if enemy.is_in_group("bosses"):
			continue
		if not is_instance_valid(enemy) or not enemy.visible:
			continue
		
		var dist = global_position.distance_to(enemy.global_position)
		if dist > heal_range_val:
			continue
		
		var health = enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive() and health.current_health < health.max_health:
			health.heal(heal_amt)
			_spawn_heal_vfx(enemy.global_position)
			return # Cura um por vez


func _find_wounded_ally() -> CharacterBody2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest: CharacterBody2D = null
	var closest_dist := INF
	
	for enemy in enemies:
		if enemy == self:
			continue
		if enemy.is_in_group("bosses"):
			continue
		if not is_instance_valid(enemy) or not enemy.visible:
			continue
		
		var health = enemy.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue
		if health.current_health >= health.max_health:
			continue
		
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy as CharacterBody2D
	
	return closest


func _spawn_heal_vfx(pos: Vector2) -> void:
	if DamageNumbers:
		DamageNumbers.show_number(enemy_data.heal_amount if enemy_data else 10.0, pos, false, true)


func reset(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_contact_cooldown = 0.0
	_knockback_velocity = Vector2.ZERO
	var health := get_node_or_null("HealthComponent") as HealthComponent
	if health:
		if enemy_data:
			health.max_health = enemy_data.max_health
		health.reset()
	_player = _find_player()
	_heal_timer = enemy_data.heal_interval if enemy_data else 3.0


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null
