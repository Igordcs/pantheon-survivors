extends ColorRect
class_name DamageFeedback
## Brief soft red vignette displayed when the player takes damage.

@export_range(0.0, 1.0, 0.05) var maximum_intensity: float = 0.72
@export_range(0.05, 1.5, 0.05) var fade_duration: float = 0.42

var _fade_tween: Tween
var _shader_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = material as ShaderMaterial
	_set_intensity(0.0)
	hide()


func flash_damage(_damage_amount: float = 0.0) -> void:
	if _shader_material == null:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	show()
	_set_intensity(maximum_intensity)
	_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_method(_set_intensity, maximum_intensity, 0.0, fade_duration)
	_fade_tween.tween_callback(hide)


func get_intensity() -> float:
	if _shader_material == null:
		return 0.0
	return float(_shader_material.get_shader_parameter("intensity"))


func _set_intensity(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("intensity", value)
