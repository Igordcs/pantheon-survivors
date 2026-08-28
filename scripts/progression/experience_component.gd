extends Node
class_name ExperienceComponent
## Gerencia XP e nível do Player.

signal experience_changed(current_xp: int, xp_needed: int)
signal level_up(new_level: int)

var current_xp: int = 0
var current_level: int = 1


func xp_for_next_level() -> int:
	return 10 + (current_level * 5)


func add_xp(amount: int) -> void:
	current_xp += amount
	var needed := xp_for_next_level()
	while current_xp >= needed:
		current_xp -= needed
		current_level += 1
		level_up.emit(current_level)
		needed = xp_for_next_level()
	experience_changed.emit(current_xp, xp_for_next_level())
