extends Area2D
signal currency_collected(amount: int)
## PickupArea — coleta XP Gems e outros pickups para o Player.


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	# Pickups reativados pelo pool podem surgir já sobrepostos e não emitir
	# area_entered novamente. A varredura garante a coleta nesses casos.
	for area in get_overlapping_areas():
		_collect_area(area)


func _on_area_entered(area: Area2D) -> void:
	_collect_area(area)


func _collect_area(area: Area2D) -> void:
	var collected := false
	if area.is_in_group("xp_gems") and area.has_method("collect"):
		var xp_value: int = area.collect()
		if xp_value > 0:
			var exp_comp := get_parent().get_node_or_null("ExperienceComponent") as ExperienceComponent
			if exp_comp:
				exp_comp.add_xp(xp_value)
				collected = true
	elif area.is_in_group("coins") and area.has_method("collect"):
		var amount: int = area.collect()
		if amount > 0 and SaveManager.add_currency(amount):
			currency_collected.emit(amount)
			collected = true
	if collected:
		var controller := get_parent().get_node_or_null("ItemEffectController") as ItemEffectController
		if controller: controller.notify_pickup()
