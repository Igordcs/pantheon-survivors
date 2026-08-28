extends CharacterBody2D
## Player — movimento em 8 direções com WASD/setas.

@export var speed: float = 200.0

var last_direction: Vector2 = Vector2.RIGHT


func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
	move_and_slide()

	# Update facing direction
	if input_dir != Vector2.ZERO:
		last_direction = input_dir.normalized()
		
	# Flip sprite based on horizontal movement
	if input_dir.x != 0.0:
		$Sprite2D.flip_h = input_dir.x < 0.0
