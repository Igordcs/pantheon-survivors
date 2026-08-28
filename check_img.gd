extends SceneTree

func _init() -> void:
	var tex = Image.load_from_file("res://assets/sprites/characters/vampire/Run/Vampires2_Run_full.png")
	if tex:
		print("Dimensions: ", tex.get_width(), "x", tex.get_height())
	else:
		print("Failed to load image.")
	quit()
