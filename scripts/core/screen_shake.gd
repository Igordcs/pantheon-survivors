extends Node
## ScreenShake — Aplica trauma em uma câmera ativa.

var _camera: Camera2D
var _trauma: float = 0.0
var _max_shake: float = 20.0
var _decay: float = 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _trauma > 0.0:
		_trauma = maxf(_trauma - _decay * delta, 0.0)
		_apply_shake()
	elif _camera:
		_camera.offset = Vector2.ZERO


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)
	
	# Encontra a câmera se não tiver
	if not is_instance_valid(_camera):
		var cam = get_viewport().get_camera_2d()
		if cam:
			_camera = cam


func _apply_shake() -> void:
	if not is_instance_valid(_camera):
		return
		
	var amount = _trauma * _trauma
	_camera.offset = Vector2(
		randf_range(-1.0, 1.0) * _max_shake * amount,
		randf_range(-1.0, 1.0) * _max_shake * amount
	)
