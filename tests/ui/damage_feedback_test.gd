extends Node

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var feedback_scene := load("res://scenes/ui/damage_feedback.tscn") as PackedScene
	var feedback := feedback_scene.instantiate() as DamageFeedback
	add_child(feedback)
	await get_tree().process_frame
	if feedback.visible:
		_fail("Damage feedback should start hidden.")

	feedback.flash_damage(10.0)
	if not feedback.visible:
		_fail("Damage feedback should become visible after a hit.")
	if feedback.get_intensity() <= 0.0:
		_fail("Damage feedback should start with a visible red intensity.")

	await get_tree().create_timer(feedback.fade_duration + 0.1).timeout
	if feedback.visible or feedback.get_intensity() > 0.001:
		_fail("Damage feedback should fade out and hide itself.")

	if _failures == 0:
		print("Damage feedback tests passed.")
	get_tree().quit(_failures)


func _fail(message: String) -> void:
	_failures += 1
	push_error("Damage feedback test: %s" % message)
