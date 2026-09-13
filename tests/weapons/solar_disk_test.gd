extends Node

const SOLAR_DISK_SCENE := preload("res://scenes/weapons/solar_disk.tscn")
const ENEMY_PROJECTILE_SCENE := preload("res://scenes/weapons/enemy_projectile.tscn")

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var solar_disk := SOLAR_DISK_SCENE.instantiate() as Node2D
	add_child(solar_disk)
	await get_tree().physics_frame

	if solar_disk.get_disk_count() != 1:
		_fail("Solar Disk should start with one orbiting disk.")

	for _index in range(12):
		solar_disk.upgrade()
	if solar_disk.get_disk_count() != 3:
		_fail("Solar Disk must enforce a hard maximum of three orbiting disks.")

	var weapon_data := solar_disk.weapon_data as WeaponData
	for level in range(1, weapon_data.max_level + 1):
		var level_data := weapon_data.get_level_data(level)
		if level_data and level_data.projectile_count > 3:
			_fail("Solar Disk level %d configures more than three disks." % level)

	var projectile := ENEMY_PROJECTILE_SCENE.instantiate() as Area2D
	add_child(projectile)
	projectile.global_position = (
		solar_disk.get_node("DiskArea") as Area2D
	).global_position
	solar_disk.call("_block_enemy_projectiles")
	if not projectile.is_queued_for_deletion():
		_fail("An enemy projectile touching a Solar Disk should be blocked.")

	if _failures == 0:
		print("Solar Disk tests passed.")
	get_tree().quit(_failures)


func _fail(message: String) -> void:
	_failures += 1
	push_error("Solar Disk test: %s" % message)
