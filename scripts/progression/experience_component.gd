extends Node
class_name ExperienceComponent
## Gerencia XP e nível do Player.

signal experience_changed(current_xp: int, xp_needed: int)
signal level_up(new_level: int)

@export_category("XP Progression")
@export_range(1, 1000, 1) var base_xp_requirement: int = 30
@export_range(1, 100, 1) var xp_growth_per_level: int = 8
@export_range(0.0, 10.0, 0.05) var xp_growth_acceleration: float = 0.75

var current_xp: int = 0
var current_level: int = 1


func xp_for_next_level() -> int:
	return get_xp_requirement_for_level(current_level)


func get_xp_requirement_for_level(level: int) -> int:
	var level_index := maxi(level - 1, 0)
	var gradual_growth := (
		base_xp_requirement
		+ xp_growth_per_level * level_index
		+ xp_growth_acceleration * level_index * level_index
	)
	return maxi(roundi(gradual_growth), 1)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	var needed := xp_for_next_level()
	while current_xp >= needed:
		current_xp -= needed
		current_level += 1
		level_up.emit(current_level)
		needed = xp_for_next_level()
	experience_changed.emit(current_xp, xp_for_next_level())
