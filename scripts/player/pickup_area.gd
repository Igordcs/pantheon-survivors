extends Area2D
## PickupArea — coleta XP Gems e outros pickups para o Player.


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("xp_gems") and area.has_method("collect"):
		var xp_value: int = area.collect()
		if xp_value > 0:
			var exp_comp := get_parent().get_node_or_null("ExperienceComponent") as ExperienceComponent
			if exp_comp:
				exp_comp.add_xp(xp_value)
