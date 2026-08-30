extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var player := Node2D.new()
	var camera := GameCameraController.new()
	var boss := Node2D.new()
	root.add_child(player)
	player.add_child(camera)
	root.add_child(boss)
	await process_frame

	if camera.gameplay_zoom >= 1.4:
		_fail("Gameplay zoom should expose more world area than the previous camera.")

	boss.global_position = Vector2(600.0, 0.0)
	camera.focus_boss(boss)
	camera._process(0.1)
	if camera.top_level:
		_fail("Boss framing must not detach the camera from the player.")
	if camera.position.x <= 0.0 or camera.position.x >= 300.0:
		_fail("The camera did not begin a smooth transition toward the midpoint.")

	for _index in range(30):
		camera._process(0.1)
	if camera.position.distance_to(Vector2(300.0, 0.0)) > 1.0:
		_fail("The camera did not settle between the player and boss.")

	var focused_position := camera.position
	camera.release_boss()
	camera._process(0.1)
	if camera.position.x >= focused_position.x:
		_fail("The camera did not begin returning to the player.")
	for _index in range(30):
		camera._process(0.1)
	if camera.position.length() > 1.0:
		_fail("The camera did not return to the player after the boss encounter.")
	if not is_equal_approx(camera.zoom.x, camera.gameplay_zoom):
		_fail("The camera did not restore its gameplay zoom.")

	boss.free()
	player.free()
	if _failures == 0:
		print("GameCameraController tests passed.")
	quit(_failures)


func _fail(message: String) -> void:
	_failures += 1
	push_error("GameCameraController test: %s" % message)
