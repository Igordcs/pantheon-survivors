extends Area2D
class_name CoinPickup

var _amount: int = 0
var _collected: bool = false
var _available_for_reuse: bool = false


func setup(spawn_position: Vector2, amount: int) -> void:
	global_position = spawn_position
	_amount = maxi(amount, 0)
	_collected = false
	_available_for_reuse = false
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	set_deferred("collision_layer", 8)
	set_process(true)


func collect() -> int:
	if _collected or _amount <= 0:
		return 0
	_collected = true
	var result := _amount
	_amount = 0
	visible = false
	set_process(false)
	call_deferred("_finish_deactivation")
	return result


func is_available_for_reuse() -> bool:
	return _available_for_reuse


func _finish_deactivation() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	global_position = Vector2(-9999.0, -9999.0)
	_available_for_reuse = true
