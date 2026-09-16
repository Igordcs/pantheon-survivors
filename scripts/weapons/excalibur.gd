extends Node2D
## Excalibur — giro de 360° ao redor do personagem, atingindo todos os inimigos próximos.

signal weapon_upgraded(weapon_id: StringName, new_level: int)

@export var weapon_data: WeaponData = preload("res://resources/weapons/excalibur_data.tres")

var _cooldown_timer: Timer
var _current_level: int = 1
var _damage: float = 11.0
var _front_strikes: int = 1
var _rear_strikes: int = 0
var _life_steal_ratio: float = 0.0
var _is_attacking: bool = false
var _hit_this_spin: Dictionary = {}

@onready var _hitbox: Area2D = $Hitbox
@onready var _attack_visual: Node2D = $Hitbox/AttackVisual
@onready var _sweep_blade: Node2D = $Hitbox/AttackVisual/SweepBlade


func _ready() -> void:
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	_hitbox.monitoring = false
	_hitbox.visible = false
	_apply_level_stats()
	_cooldown_timer.start()


func get_weapon_id() -> StringName:
	return weapon_data.id if weapon_data else &"excalibur"


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
	# Hitbox base compacta (~70% do arco original); os níveis quase não aumentam o alcance.
	_hitbox.scale = Vector2.ONE * 0.7 * level_data.area_multiplier
	_front_strikes = 1
	_rear_strikes = 0
	_life_steal_ratio = 0.0
	match level_data.special_effect:
		&"front_rear_combo":
			_rear_strikes = 1
		&"double_front_rear_combo":
			_front_strikes = 2
			_rear_strikes = 1
		&"double_rear_front_combo":
			_front_strikes = 1
			_rear_strikes = 2
		&"royal_life_steal_combo":
			_front_strikes = 1
			_rear_strikes = 2
			_life_steal_ratio = level_data.special_value

	if _cooldown_timer:
		_cooldown_timer.wait_time = maxf(0.2, weapon_data.cooldown * level_data.cooldown_multiplier)


func _on_cooldown_timeout() -> void:
	if not _is_attacking:
		_attack_sequence()


func _attack_sequence() -> void:
	_is_attacking = true

	# Cada "strike" agora é um giro completo de 360°.
	# _front_strikes + _rear_strikes = total de giros (herdado da lógica de combos).
	var total_spins := _front_strikes + _rear_strikes
	for index in range(total_spins):
		await _play_spin()
		if index < total_spins - 1:
			await get_tree().create_timer(0.08, false).timeout

	_is_attacking = false
	_cooldown_timer.start()


func _play_spin() -> void:
	MusicManager.play_excalibur_sfx()

	_hit_this_spin.clear()
	_hitbox.rotation = 0.0
	_hitbox.modulate = Color.WHITE
	_attack_visual.scale = Vector2.ONE * 0.82
	_sweep_blade.rotation = deg_to_rad(-55.0)
	_hitbox.visible = true
	_hitbox.monitoring = true
	# Dano aplicado via body_entered durante o giro — captura todos os inimigos tocados.
	_hitbox.body_entered.connect(_on_spin_body_entered)

	# O hitbox gira 360° enquanto a lâmina faz o sweep visual.
	var spin_tween := _hitbox.create_tween()
	spin_tween.set_parallel(true)
	spin_tween.tween_property(_hitbox, "rotation", TAU, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	spin_tween.tween_property(_sweep_blade, "rotation", deg_to_rad(55.0), 0.4) \
		.set_trans(Tween.TRANS_LINEAR)
	spin_tween.tween_property(_attack_visual, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await spin_tween.finished

	if _hitbox.body_entered.is_connected(_on_spin_body_entered):
		_hitbox.body_entered.disconnect(_on_spin_body_entered)

	var fade_tween := create_tween()
	fade_tween.tween_property(_hitbox, "modulate:a", 0.0, 0.12)
	await fade_tween.finished
	_hitbox.monitoring = false
	_hitbox.visible = false
	_hit_this_spin.clear()


## Chamado pelo sinal body_entered do hitbox durante o giro.
## Aplica dano no instante em que o arco toca o inimigo, evitando double-hit.
func _on_spin_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or not body.visible:
		return
	if _hit_this_spin.has(body):
		return
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if not health or not health.is_alive():
		return
	var actual := minf(_damage, health.current_health)
	health.take_damage(_damage, global_position)
	_hit_this_spin[body] = true
	_apply_life_steal(actual)

	# Efeito visual de hit: flash rápido no arco
	_attack_visual.modulate = Color(2.0, 1.8, 0.6, 1.0)
	var flash := _attack_visual.create_tween()
	flash.tween_property(_attack_visual, "modulate", Color.WHITE, 0.07)


func _apply_life_steal(damage_dealt: float) -> void:
	if _life_steal_ratio <= 0.0:
		return
	var player := _get_player()
	if not player:
		return
	var player_health := player.get_node_or_null("HealthComponent") as HealthComponent
	if player_health and player_health.is_alive():
		player_health.heal(damage_dealt * _life_steal_ratio)


func _get_player() -> CharacterBody2D:
	return get_parent().get_parent() as CharacterBody2D
