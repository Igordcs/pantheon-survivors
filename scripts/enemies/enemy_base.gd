extends CharacterBody2D
class_name EnemyBase
## Comportamentos de combate compartilhados por todos os inimigos.

const PETRIFIED_COLOR := Color(0.55, 0.62, 0.68, 1.0)

var _knockback_velocity: Vector2 = Vector2.ZERO
var _petrification_timer: float = 0.0


func apply_knockback_from(source_position: Vector2, force: float = 200.0) -> void:
	_knockback_velocity = source_position.direction_to(global_position) * force


func apply_petrification(duration: float) -> void:
	_petrification_timer = maxf(_petrification_timer, duration)
	_knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	var visual := _get_effect_visual()
	if visual:
		visual.self_modulate = PETRIFIED_COLOR


func _process_petrification(delta: float) -> bool:
	if _petrification_timer <= 0.0:
		return false
	_petrification_timer = maxf(_petrification_timer - delta, 0.0)
	velocity = Vector2.ZERO
	move_and_slide()
	if _petrification_timer <= 0.0:
		_reset_effect_visual()
	return true


func _reset_combat_effects() -> void:
	_knockback_velocity = Vector2.ZERO
	_petrification_timer = 0.0
	_reset_effect_visual()


func _reset_effect_visual() -> void:
	var visual := _get_effect_visual()
	if visual:
		visual.self_modulate = Color.WHITE


func _get_effect_visual() -> CanvasItem:
	var static_sprite := get_node_or_null("Sprite2D") as CanvasItem
	if static_sprite:
		return static_sprite
	return get_node_or_null("AnimatedSprite2D") as CanvasItem
