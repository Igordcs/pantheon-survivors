extends Node2D

var _radius: float = 0.0
var _alpha: float = 1.0
var _color_main := Color(1.0, 0.4, 0.0)
var _color_glow := Color(1.0, 0.1, 0.0)
var _color_sparks := Color(1.0, 0.9, 0.0)

func _process(delta: float) -> void:
	_radius += delta * 130.0 # Reduzido para cerca de 1/3 do tamanho
	_alpha -= delta * 2.0
	if _alpha <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	if _alpha > 0.0:
		var c1 = _color_main
		c1.a = _alpha
		var c2 = _color_glow
		c2.a = _alpha * 0.5
		var c3 = _color_sparks
		c3.a = _alpha
		
		# Anel de fogo
		draw_arc(Vector2.ZERO, _radius, 0, TAU, 32, c1, 8.0)
		# Preenchimento fraco da explosão
		draw_circle(Vector2.ZERO, _radius * 0.7, c2)
		
		# Faíscas espalhadas
		for i in range(8):
			var a = i * (TAU / 8.0) + _radius * 0.05
			var p = Vector2(cos(a), sin(a)) * _radius * 1.3
			draw_circle(p, 5.0, c3)
