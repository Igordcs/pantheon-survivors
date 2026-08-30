class_name GameCameraController
extends Camera2D
## Smoothly frames normal gameplay and boss encounters without changing parents.

@export_category("Gameplay View")
@export_range(0.5, 2.0, 0.05) var gameplay_zoom: float = 1.1

@export_category("Boss Framing")
@export_range(0.5, 1.5, 0.05) var minimum_boss_zoom: float = 0.8
@export_range(64.0, 400.0, 8.0) var framing_padding: float = 180.0
@export_range(1.0, 12.0, 0.5) var transition_speed: float = 4.0

var _boss_target: Node2D
var _is_framing_boss: bool = false


func _ready() -> void:
	zoom = Vector2.ONE * gameplay_zoom


func focus_boss(boss: Node2D) -> void:
	if not is_instance_valid(boss):
		return
	_boss_target = boss
	_is_framing_boss = true


func release_boss() -> void:
	_is_framing_boss = false
	_boss_target = null


func _process(delta: float) -> void:
	if _is_framing_boss and not is_instance_valid(_boss_target):
		release_boss()

	var target_position := Vector2.ZERO
	var target_zoom := gameplay_zoom
	if _is_framing_boss:
		target_position = _get_boss_framing_position()
		target_zoom = _get_boss_framing_zoom()

	var blend := 1.0 - exp(-transition_speed * delta)
	position = position.lerp(target_position, blend)
	zoom = zoom.lerp(Vector2.ONE * target_zoom, blend)


func _get_boss_framing_position() -> Vector2:
	var player := get_parent() as Node2D
	if player == null:
		return Vector2.ZERO
	var midpoint := (player.global_position + _boss_target.global_position) * 0.5
	return player.to_local(midpoint)


func _get_boss_framing_zoom() -> float:
	var player := get_parent() as Node2D
	if player == null:
		return gameplay_zoom
	var half_separation := (
		player.global_position - _boss_target.global_position
	).abs() * 0.5
	var required_half_size := half_separation + Vector2.ONE * framing_padding
	var viewport_half_size := get_viewport_rect().size * 0.5
	var horizontal_zoom := viewport_half_size.x / maxf(required_half_size.x, 1.0)
	var vertical_zoom := viewport_half_size.y / maxf(required_half_size.y, 1.0)
	return clampf(
		minf(horizontal_zoom, vertical_zoom),
		minimum_boss_zoom,
		gameplay_zoom
	)
