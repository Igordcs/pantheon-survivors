extends Node

var _failures: int = 0


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var experience := ExperienceComponent.new()
	add_child(experience)
	await get_tree().process_frame

	var expected_requirements := {
		1: 30,
		2: 39,
		3: 49,
		5: 74,
		10: 163,
		20: 453,
	}
	for level in expected_requirements:
		var requirement := experience.get_xp_requirement_for_level(level)
		if requirement != expected_requirements[level]:
			_fail(
				"Level %d should require %d XP, received %d."
				% [level, expected_requirements[level], requirement]
			)

	var previous_requirement := 0
	for level in range(1, 51):
		var requirement := experience.get_xp_requirement_for_level(level)
		if requirement <= previous_requirement:
			_fail("XP requirement should increase at level %d." % level)
		previous_requirement = requirement

	experience.add_xp(29)
	if experience.current_level != 1 or experience.current_xp != 29:
		_fail("The player should not level up before reaching 30 XP.")
	experience.add_xp(1)
	if experience.current_level != 2 or experience.current_xp != 0:
		_fail("The first level-up should happen at exactly 30 XP.")
	experience.add_xp(40)
	if experience.current_level != 3 or experience.current_xp != 1:
		_fail("Excess XP should carry over to the next level.")

	if _failures == 0:
		print("Experience progression tests passed.")
	get_tree().quit(_failures)


func _fail(message: String) -> void:
	_failures += 1
	push_error("Experience progression test: %s" % message)
