extends Area2D
## Mjölnir arremessado — avança, retorna ao portador e causa dano nas duas fases.

signal hit_enemy(enemy: Node2D, impact_position: Vector2, dealt_damage: float)

enum FlightPhase { OUTBOUND, RETURNING }

var direction: Vector2 = Vector2.ZERO
var speed: float = 600.0
var damage: float = 15.0
var max_distance: float = 250.0

var _wielder: Node2D
var _flight_phase: FlightPhase = FlightPhase.OUTBOUND
var _distance_traveled: float = 0.0
var _turnaround_delay: float = 0.0
var _outbound_hits: Dictionary = {}
var _return_hits: Dictionary = {}
var _trail_points: Array[Vector2] = []

@onready var _hammer_visual: Node2D = $HammerVisual
@onready var _trail: Line2D = $Trail


func _ready() -> void:
	_trail.top_level = true
	_trail.global_position = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_wielder):
		queue_free()
		return

	_hammer_visual.rotation += TAU * 2.8 * delta
	match _flight_phase:
		FlightPhase.OUTBOUND:
			_process_outbound(delta)
		FlightPhase.RETURNING:
			_process_return(delta)

	_update_trail()
	_damage_overlapping_enemies()


func setup(
	wielder: Node2D,
	dir: Vector2,
	spd: float,
	dmg: float,
	max_dist: float = 250.0
) -> void:
	_wielder = wielder
	direction = dir.normalized()
	speed = spd
	damage = dmg
	max_distance = max_dist
	_flight_phase = FlightPhase.OUTBOUND
	_distance_traveled = 0.0
	_turnaround_delay = 0.0
	_outbound_hits.clear()
	_return_hits.clear()


func _process_outbound(delta: float) -> void:
	if _distance_traveled >= max_distance:
		_turnaround_delay -= delta
		if _turnaround_delay <= 0.0:
			_flight_phase = FlightPhase.RETURNING
			_trail.default_color = Color(0.7, 0.92, 1.0, 0.9)
		return

	var remaining_distance := maxf(max_distance - _distance_traveled, 0.0)
	var movement_distance := minf(speed * delta, remaining_distance)
	global_position += direction * movement_distance
	_distance_traveled += movement_distance
	if _distance_traveled >= max_distance:
		# Mantém o martelo brevemente no limite para a física registrar o último
		# contato da ida antes de iniciar uma nova fase de acertos na volta.
		_turnaround_delay = 0.06
		_spawn_turnaround_vfx()


func _process_return(delta: float) -> void:
	var distance_to_wielder := global_position.distance_to(_wielder.global_position)
	var return_step := speed * 1.15 * delta
	if distance_to_wielder <= maxf(return_step, 16.0):
		global_position = _wielder.global_position
		queue_free()
		return
	direction = global_position.direction_to(_wielder.global_position)
	global_position += direction * return_step


func _damage_overlapping_enemies() -> void:
	var hit_registry := _outbound_hits if _flight_phase == FlightPhase.OUTBOUND else _return_hits
	for body in get_overlapping_bodies():
		if not body.is_in_group("enemies") or not body.visible:
			continue
		var instance_id := body.get_instance_id()
		if hit_registry.has(instance_id):
			continue
		var health := body.get_node_or_null("HealthComponent") as HealthComponent
		if not health or not health.is_alive():
			continue
		hit_registry[instance_id] = true
		health.take_damage(damage, global_position)
		hit_enemy.emit(body, global_position, damage)
		ScreenShake.shake(0.14)
		AudioManager.play_sfx("mjolnir_hit")


func _update_trail() -> void:
	_trail_points.push_front(global_position)
	if _trail_points.size() > 9:
		_trail_points.pop_back()
	_trail.points = PackedVector2Array(_trail_points)


func _spawn_turnaround_vfx() -> void:
	var ring := Line2D.new()
	ring.default_color = Color(0.45, 0.85, 1.0, 0.9)
	ring.width = 4.0
	for index in range(17):
		ring.add_point(Vector2.from_angle(TAU * float(index) / 16.0) * 20.0)
	add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.8, 0.16)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.tween_callback(ring.queue_free)
