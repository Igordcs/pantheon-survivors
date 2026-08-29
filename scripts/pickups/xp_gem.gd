extends Area2D
## XP Gem — drop de experiência ao matar inimigos.

@export var xp_value: int = 5

var _collected: bool = false


func setup(pos: Vector2, value: int) -> void:
	global_position = pos
	xp_value = value
	_collected = false
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func collect() -> int:
	if _collected:
		return 0
	_collected = true
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	global_position = Vector2(-9999, -9999)
	return xp_value
