extends Node
## DamageNumbers — Sistema para exibir números de dano flutuantes.

var number_scene: PackedScene = preload("res://scenes/ui/damage_number.tscn")

func show_number(value: float, pos: Vector2, is_critical: bool = false, is_heal: bool = false) -> void:
	if not number_scene:
		return
		
	var lbl = number_scene.instantiate() as Label
	lbl.text = str(int(value))
	lbl.global_position = pos + Vector2(randf_range(-10, 10), -20)
	
	if is_heal:
		lbl.modulate = Color.GREEN
	elif is_critical:
		lbl.modulate = Color.YELLOW
		lbl.scale = Vector2(1.5, 1.5)
	else:
		lbl.modulate = Color.WHITE
		
	get_tree().current_scene.add_child(lbl)
	
	# Tween para flutuar e sumir
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", lbl.global_position.y - 40, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.2)
	tween.tween_callback(lbl.queue_free)
