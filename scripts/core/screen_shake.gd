extends Node
## ScreenShake — Aplica trauma em uma câmera ativa com decaimento suave.

var _camera: Camera2D
var _trauma: float = 0.0
var _max_shake: float = 22.0
var _decay: float = 1.2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_camera(cam: Camera2D) -> void:
	_camera = cam


func _resolve_camera() -> Camera2D:
	if is_instance_valid(_camera):
		return _camera
	var viewport := get_viewport()
	if viewport:
		var cam := viewport.get_camera_2d()
		if is_instance_valid(cam):
			_camera = cam
			return _camera
	var tree := get_tree()
	if tree and tree.current_scene:
		var found := tree.current_scene.find_child("Camera2D", true, false) as Camera2D
		if is_instance_valid(found):
			_camera = found
			return _camera
	return null


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - _decay * delta, 0.0)
		_apply_shake()
	else:
		var cam := _resolve_camera()
		if cam:
			cam.offset = Vector2.ZERO


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)
	_resolve_camera()


func _apply_shake() -> void:
	var cam := _resolve_camera()
	if not cam:
		return

	var amount := _trauma * _trauma
	cam.offset = Vector2(
		randf_range(-1.0, 1.0) * _max_shake * amount,
		randf_range(-1.0, 1.0) * _max_shake * amount
	)
