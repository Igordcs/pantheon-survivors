extends Node

const CHARACTER_IDS: Array[StringName] = [
	&"eirik", &"arthur", &"neferu", &"perseus", &"punisher", &"kratos",
]
const ENEMY_IDLE_IDS: Array[StringName] = [
	&"ammit", &"corrupted_valkyrie", &"cyclops", &"draugr",
	&"harpy", &"medusa", &"minotaur", &"mummy",
]
const ENEMY_WALK_IDS: Array[StringName] = [
	&"ammit", &"corrupted_valkyrie", &"cyclops", &"draugr", &"mummy",
]
const BOSS_IDLE_IDS: Array[StringName] = [
	&"cerberus", &"jormungandr", &"fenrir", &"lernaean_hydra",
	&"amheh", &"anubis", &"apophis",
]
const BOSS_WALK_IDS: Array[StringName] = [&"cerberus", &"fenrir", &"amheh", &"anubis"]

var _failures := 0


func _ready() -> void:
	for character_id in CHARACTER_IDS:
		_validate_character(character_id)
	for enemy_id in ENEMY_IDLE_IDS:
		_validate_enemy_idle(enemy_id)
	for enemy_id in ENEMY_WALK_IDS:
		_validate_enemy_walk(enemy_id)
	for boss_id in BOSS_IDLE_IDS:
		_validate_boss_idle(boss_id)
	for boss_id in BOSS_WALK_IDS:
		_validate_boss_walk(boss_id)
	_validate_authored_scene_animations()
	if _failures == 0:
		print("Actor animation audit tests passed.")
	get_tree().quit(_failures)


func _validate_character(character_id: StringName) -> void:
	var data := ContentRegistry.get_character_data(character_id)
	if not data:
		_fail("Missing character data for %s." % character_id)
		return
	for direction_name in DirectionalSpriteHelper.DIRECTION_NAMES:
		var direction := _direction_vector(direction_name)
		var idle := data.get_gameplay_sprite(direction)
		if not idle or not idle.resource_path.ends_with("/%s.png" % direction_name):
			_fail("%s idle %s is missing or points to another direction." % [character_id, direction_name])
		_validate_frames(character_id, direction_name, data.get_walk_frames(direction))


func _validate_enemy_idle(enemy_id: StringName) -> void:
	var data := ContentRegistry.get_enemy_data(enemy_id)
	if not data:
		_fail("Missing enemy data for %s." % enemy_id)
		return
	for direction_name in DirectionalSpriteHelper.DIRECTION_NAMES:
		var texture := data.get_directional_sprite(_direction_vector(direction_name))
		if not texture or not texture.resource_path.ends_with("/%s.png" % direction_name):
			_fail("%s idle %s is missing or points to another direction." % [enemy_id, direction_name])


func _validate_enemy_walk(enemy_id: StringName) -> void:
	var data := ContentRegistry.get_enemy_data(enemy_id)
	if not data or not data.has_walk_animation():
		_fail("%s has authored walk assets but no configured walk animation." % enemy_id)
		return
	for direction_name in DirectionalSpriteHelper.DIRECTION_NAMES:
		var direction := _direction_vector(direction_name)
		var frames: Array[Texture2D] = []
		for frame_index in DirectionalSpriteHelper.ANIMATION_FRAME_COUNT:
			frames.append(data.get_walk_frame(direction, frame_index))
		_validate_frames(enemy_id, direction_name, frames)


func _validate_boss_idle(boss_id: StringName) -> void:
	var data := ContentRegistry.get_boss_data(boss_id)
	if not data:
		_fail("Missing boss data for %s." % boss_id)
		return
	for direction_name in DirectionalSpriteHelper.DIRECTION_NAMES:
		var texture := data.get_directional_sprite(_direction_vector(direction_name))
		if not texture or not texture.resource_path.ends_with("/%s.png" % direction_name):
			_fail("%s idle %s is missing or points to another direction." % [boss_id, direction_name])


func _validate_boss_walk(boss_id: StringName) -> void:
	var data := ContentRegistry.get_boss_data(boss_id)
	if not data or not data.has_walk_animation():
		_fail("%s has authored walk assets but no configured walk animation." % boss_id)
		return
	for direction_name in DirectionalSpriteHelper.DIRECTION_NAMES:
		var direction := _direction_vector(direction_name)
		var frames: Array[Texture2D] = []
		for frame_index in DirectionalSpriteHelper.ANIMATION_FRAME_COUNT:
			frames.append(data.get_walk_frame(direction, frame_index))
		_validate_frames(boss_id, direction_name, frames)


func _validate_frames(actor_id: StringName, direction_name: StringName, frames: Array[Texture2D]) -> void:
	if frames.size() != DirectionalSpriteHelper.ANIMATION_FRAME_COUNT:
		_fail("%s/%s should have %d walk frames, found %d." % [
			actor_id, direction_name, DirectionalSpriteHelper.ANIMATION_FRAME_COUNT, frames.size(),
		])
		return
	for frame in frames:
		if not frame or "/%s/" % direction_name not in frame.resource_path:
			_fail("%s walk %s contains a frame from another direction." % [actor_id, direction_name])
			return


func _validate_authored_scene_animations() -> void:
	var orc_scene := load("res://scenes/bosses/orc_warlord.tscn") as PackedScene
	var orc := orc_scene.instantiate()
	if String(orc.get("idle_directory")) != "res://assets/sprites/bosses/orc_warlord/idle" \
			or String(orc.get("run_directory")) != "res://assets/sprites/bosses/orc_warlord/run":
		_fail("Orc Warlord should use separate idle and run directories.")
	orc.free()


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
	push_error("Actor animation audit: %s" % message)
