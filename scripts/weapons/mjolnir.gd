extends Node2D
## Mjolnir — arma targeted automática. Dispara projéteis no inimigo mais próximo.

@export var weapon_data: WeaponData
@export var projectile_scene: PackedScene

var _cooldown_timer: Timer


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.wait_time = weapon_data.cooldown if weapon_data else 1.2
	_cooldown_timer.one_shot = false
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)


func _on_cooldown_timeout() -> void:
	var target := _find_closest_enemy()
	if target == null:
		return
	_fire_at(target)


func _find_closest_enemy() -> CharacterBody2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var range_sq := (weapon_data.area * weapon_data.area) if weapon_data else 62500.0
	var closest: CharacterBody2D = null
	var closest_dist_sq := range_sq

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


func _fire_at(target: CharacterBody2D) -> void:
	if projectile_scene == null:
		return
	var proj := projectile_scene.instantiate() as Area2D
	var dir := global_position.direction_to(target.global_position)
	var dist := global_position.distance_to(target.global_position)

	proj.global_position = global_position
	proj.setup(
		dir,
		weapon_data.projectile_speed if weapon_data else 600.0,
		weapon_data.base_damage if weapon_data else 15.0,
		dist + 50.0
	)

	# Add projectile to the scene root, not to the weapon
	get_tree().current_scene.add_child(proj)
