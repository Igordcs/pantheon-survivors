extends DirectionalBoss
## Cerberus alternates three separated fire cones with a targeted crushing leap.

enum AttackType { TRIPLE_BREATH, CRUSHING_LEAP }
enum State { CHASING, TELEGRAPHING, RECOVERING }

@export var attack_cooldown: float = 4.2
@export var telegraph_duration: float = 0.9
@export var breath_damage: float = 28.0
@export var breath_range: float = 290.0
@export var breath_half_angle_degrees: float = 13.0
@export var breath_spread_degrees: float = 38.0
@export var leap_damage: float = 38.0
@export var leap_radius: float = 105.0

var _state := State.CHASING
var _state_timer: float = 2.4
var _attack_type := AttackType.TRIPLE_BREATH
var _attack_origin := Vector2.ZERO
var _attack_direction := Vector2.DOWN
var _target_position := Vector2.ZERO
var _telegraphs: Array[Polygon2D] = []


func _tick_behavior(delta: float) -> void:
	_state_timer -= delta
	match _state:
		State.CHASING:
			chase_player(1.12 if health_component.current_health <= health_component.max_health * 0.5 else 1.0)
			if _state_timer <= 0.0:
				_start_attack()
		State.TELEGRAPHING:
			stop_movement()
			if _state_timer <= 0.0:
				_execute_attack()
		State.RECOVERING:
			stop_movement()
			if _state_timer <= 0.0:
				_state = State.CHASING
				_state_timer = attack_cooldown


func _start_attack() -> void:
	_state = State.TELEGRAPHING
	_state_timer = telegraph_duration
	_attack_type = AttackType.TRIPLE_BREATH if randi() % 2 == 0 else AttackType.CRUSHING_LEAP
	_attack_origin = global_position
	_attack_direction = global_position.direction_to(get_player().global_position)
	_target_position = get_player().global_position

	if _attack_type == AttackType.TRIPLE_BREATH:
		_create_breath_telegraphs()
	else:
		_create_leap_telegraph()
		sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.5)


func _execute_attack() -> void:
	if _attack_type == AttackType.TRIPLE_BREATH:
		_execute_triple_breath()
	else:
		_execute_crushing_leap()
	_state = State.RECOVERING
	_state_timer = 0.55
	ScreenShake.shake(0.7)


func _create_breath_telegraphs() -> void:
	for offset_degrees in [-breath_spread_degrees, 0.0, breath_spread_degrees]:
		var direction := _attack_direction.rotated(deg_to_rad(offset_degrees))
		var cone := Polygon2D.new()
		cone.polygon = _build_cone_polygon(breath_range, deg_to_rad(breath_half_angle_degrees))
		cone.rotation = direction.angle()
		cone.color = Color(0.95, 0.25, 0.05, 0.28)
		cone.z_index = 3
		get_tree().current_scene.add_child(cone)
		cone.global_position = _attack_origin
		_telegraphs.append(cone)


func _create_leap_telegraph() -> void:
	var marker := Polygon2D.new()
	marker.polygon = _build_circle_polygon(leap_radius)
	marker.color = Color(0.95, 0.12, 0.06, 0.3)
	marker.z_index = 3
	get_tree().current_scene.add_child(marker)
	marker.global_position = _target_position
	_telegraphs.append(marker)


func _execute_triple_breath() -> void:
	var player_hit := false
	for offset_degrees in [-breath_spread_degrees, 0.0, breath_spread_degrees]:
		var direction := _attack_direction.rotated(deg_to_rad(offset_degrees))
		if _is_player_inside_cone(direction):
			player_hit = true
	if player_hit:
		damage_player(breath_damage, _attack_origin)
	_release_telegraphs(Color(1.0, 0.32, 0.04, 0.82), 0.42)


func _execute_crushing_leap() -> void:
	global_position = _target_position
	sprite.self_modulate = Color.WHITE
	if is_player_inside_radius(_target_position, leap_radius):
		damage_player(leap_damage, _target_position)
	_release_telegraphs(Color(1.0, 0.2, 0.05, 0.78), 0.48)


func _is_player_inside_cone(direction: Vector2) -> bool:
	var offset := get_player().global_position - _attack_origin
	if offset.length_squared() > breath_range * breath_range or offset.is_zero_approx():
		return offset.is_zero_approx()
	return direction.dot(offset.normalized()) >= cos(deg_to_rad(breath_half_angle_degrees))


func _release_telegraphs(final_color: Color, fade_duration: float) -> void:
	for telegraph in _telegraphs:
		if not is_instance_valid(telegraph):
			continue
		telegraph.color = final_color
		var tween := telegraph.create_tween()
		tween.tween_property(telegraph, "modulate:a", 0.0, fade_duration)
		tween.tween_callback(telegraph.queue_free)
	_telegraphs.clear()


func _cleanup_behavior() -> void:
	for telegraph in _telegraphs:
		if is_instance_valid(telegraph):
			telegraph.queue_free()
	_telegraphs.clear()


func _build_cone_polygon(distance: float, half_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(13):
		var angle := lerpf(-half_angle, half_angle, float(index) / 12.0)
		points.append(Vector2.from_angle(angle) * distance)
	return points


func _build_circle_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(32):
		points.append(Vector2.from_angle(TAU * float(index) / 32.0) * radius)
	return points
