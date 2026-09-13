extends Node

const BAT_DATA := preload("res://resources/enemies/bat_data.tres")
const WEAPONS_THAT_ONE_HIT_BATS: Array[WeaponData] = [
	preload("res://resources/weapons/solar_disk_data.tres"),
	preload("res://resources/weapons/medusa_head_data.tres"),
]

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	for weapon_data in WEAPONS_THAT_ONE_HIT_BATS:
		var level_one := weapon_data.get_level_data(1)
		var damage_multiplier := level_one.damage_multiplier if level_one else 1.0
		var initial_damage := weapon_data.base_damage * damage_multiplier
		if initial_damage < BAT_DATA.max_health:
			_fail("%s level 1 damage %.1f cannot defeat a %.1f HP bat in one hit." % [
				weapon_data.display_name,
				initial_damage,
				BAT_DATA.max_health,
			])

	if _failures == 0:
		print("Base damage balance tests passed.")
	get_tree().quit(_failures)


func _fail(message: String) -> void:
	_failures += 1
	push_error("Base damage balance test: %s" % message)
