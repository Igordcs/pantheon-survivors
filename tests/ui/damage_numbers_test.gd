extends Node

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	DamageNumbers.show_number(42.0, Vector2.ZERO, true)
	var critical_number := get_tree().current_scene.get_node_or_null("DamageNumber") as Label
	if not critical_number:
		_fail("Critical damage should create a damage number.")
	else:
		if not critical_number.modulate.is_equal_approx(DamageNumbers.CRITICAL_COLOR):
			_fail("Critical damage numbers should use the configured orange color.")
		if not critical_number.scale.is_equal_approx(Vector2(1.5, 1.5)):
			_fail("Critical damage numbers should remain larger than normal damage.")
		critical_number.queue_free()

	if _failures == 0:
		print("Damage number tests passed.")
	get_tree().quit(_failures)


func _fail(message: String) -> void:
	_failures += 1
	push_error("Damage number test: %s" % message)
