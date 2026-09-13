extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ANIMATED_CHARACTER_IDS: Array[StringName] = [
	&"eirik",
	&"arthur",
	&"perseus",
	&"neferu",
]

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var previous_character_id := Global.selected_character_id
	for character_id in ANIMATED_CHARACTER_IDS:
		_validate_character_data(character_id)
		_validate_player_animation(character_id)
	Global.selected_character_id = previous_character_id

	if _failures == 0:
		print("Player animation tests passed.")
	get_tree().quit(_failures)


func _validate_character_data(character_id: StringName) -> void:
	var data_path := "res://resources/characters/%s_data.tres" % character_id
	var data := load(data_path) as CharacterData
	if not data:
		_fail("Could not load character data for %s." % character_id)
		return
	if not data.has_walk_animation():
		_fail("%s should have walk animations." % character_id)
		return
	for direction_name in DirectionalSpriteHelper.DIRECTION_NAMES:
		var direction := _direction_vector(direction_name)
		var frames := data.get_walk_frames(direction)
		if frames.size() != 6:
			_fail("%s/%s should have 6 walk frames, found %d." % [
				character_id, direction_name, frames.size()
			])


func _validate_player_animation(character_id: StringName) -> void:
	Global.selected_character_id = character_id
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	var animated_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if not animated_sprite:
		_fail("Player scene should use AnimatedSprite2D.")
		player.free()
		return

	player.call("_update_character_animation", Vector2.RIGHT, true)
	if animated_sprite.animation != &"walk_east":
		_fail("%s should play walk_east while moving right." % character_id)
	if animated_sprite.sprite_frames.get_frame_count(&"walk_east") != 6:
		_fail("%s walk_east animation should contain 6 frames." % character_id)

	player.call("_update_character_animation", Vector2.RIGHT, false)
	if animated_sprite.animation != &"idle_east":
		_fail("%s should return to idle_east after stopping." % character_id)
	player.free()


func _direction_vector(direction_name: StringName) -> Vector2:
	match direction_name:
		&"east": return Vector2.RIGHT
		&"south-east": return Vector2(1.0, 1.0)
		&"south": return Vector2.DOWN
		&"south-west": return Vector2(-1.0, 1.0)
		&"west": return Vector2.LEFT
		&"north-west": return Vector2(-1.0, -1.0)
		&"north": return Vector2.UP
		&"north-east": return Vector2(1.0, -1.0)
	return Vector2.DOWN


func _fail(message: String) -> void:
	_failures += 1
	push_error("Player animation test: %s" % message)
