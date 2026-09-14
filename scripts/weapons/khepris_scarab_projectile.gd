extends Node2D

var explosion_scene = preload("res://scenes/weapons/khepris_scarab_explosion.tscn")

var _wielder: Node2D
var damage: float = 3.0
var speed: float = 400.0
var tick_rate: float = 0.5
var jump_explosion_damage: float = 10.0
var jump_explosion_radius: float = 100.0
var max_jumps: int = 3
var jumps_done: int = 0

var target: CharacterBody2D
var state: int = 0 # 0 = flying, 1 = attached
var attached_enemy: CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var dot_timer: Timer = $DotTimer
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D

func setup(wielder: Node2D, dmg: float, spd: float, rate: float, expl_dmg: float, expl_rad: float, jumps: int) -> void:
	_wielder = wielder
	damage = dmg
	speed = spd
	tick_rate = rate
	jump_explosion_damage = expl_dmg
	jump_explosion_radius = expl_rad
	max_jumps = jumps
	jumps_done = 0
	
	if explosion_shape and explosion_shape.shape is CircleShape2D:
		(explosion_shape.shape as CircleShape2D).radius = jump_explosion_radius
	
	if dot_timer:
		dot_timer.wait_time = tick_rate
	
	_find_new_target()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_wielder):
		queue_free()
		return
		
	if state == 0:
		if not is_instance_valid(target) or not target.visible:
			_find_new_target()
			if not is_instance_valid(target):
				# if still no target, just fly straight or die
				queue_free()
				return
		
		var dir := global_position.direction_to(target.global_position)
		global_position += dir * speed * delta
		rotation = dir.angle() + PI/2.0
		
		if global_position.distance_to(target.global_position) < 20.0:
			_attach_to_enemy(target)
			
	elif state == 1:
		if not is_instance_valid(attached_enemy) or not attached_enemy.visible:
			_handle_enemy_death()
			return
			
		var health := attached_enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health and not health.is_alive():
			_handle_enemy_death()
			return
			
		global_position = attached_enemy.global_position
		rotation += delta * 5.0 # gira freneticamente enquanto devora

func _find_new_target() -> void:
	var closest: CharacterBody2D = null
	var closest_dist := 999999.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.visible:
			var hc = enemy.get_node_or_null("HealthComponent") as HealthComponent
			if hc and hc.is_alive():
				var d = global_position.distance_squared_to(enemy.global_position)
				if d < closest_dist:
					closest_dist = d
					closest = enemy
	target = closest

func _attach_to_enemy(enemy: CharacterBody2D) -> void:
	state = 1
	attached_enemy = enemy
	dot_timer.start()
	_apply_dot() # dano imediato

func _apply_dot() -> void:
	if is_instance_valid(attached_enemy):
		var health := attached_enemy.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			health.take_damage(damage, global_position)

func _on_dot_timer_timeout() -> void:
	if state == 1:
		_apply_dot()

func _handle_enemy_death() -> void:
	dot_timer.stop()
	state = 0
	attached_enemy = null
	
	if jump_explosion_damage > 0:
		_explode()
		
	jumps_done += 1
	if jumps_done > max_jumps:
		queue_free()
	else:
		_find_new_target()
		if not target:
			queue_free()

func _explode() -> void:
	if explosion_scene:
		var expl = explosion_scene.instantiate()
		expl.global_position = global_position
		get_tree().current_scene.add_child(expl)
		
	# Dano AoE
	for body in explosion_area.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.visible:
			var health := body.get_node_or_null("HealthComponent") as HealthComponent
			if health and health.is_alive():
				health.take_damage(jump_explosion_damage, global_position)
