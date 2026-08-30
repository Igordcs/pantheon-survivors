extends Control
## PausePanel — pausa a run e apresenta os itens obtidos e seus níveis.

@onready var inventory_text: RichTextLabel = $Panel/VBoxContainer/InventoryText
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton

var _player: CharacterBody2D
var _upgrade_system: UpgradeSystem


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(close)
	main_menu_button.pressed.connect(_on_main_menu_pressed)


func setup(player: CharacterBody2D, upgrade_system: UpgradeSystem) -> void:
	_player = player
	_upgrade_system = upgrade_system


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if event is InputEventKey and event.echo:
		return

	get_viewport().set_input_as_handled()
	if visible:
		close()
	elif not get_tree().paused:
		open()


func open() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_upgrade_system):
		push_warning("PausePanel: player ou UpgradeSystem não configurado.")
		return

	_refresh_inventory()
	show()
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false


func _refresh_inventory() -> void:
	var lines := PackedStringArray()
	var experience := _player.get_node_or_null("ExperienceComponent") as ExperienceComponent
	var hero_level := experience.current_level if experience else 1
	lines.append("[center]Nível do herói: [b]%d[/b][/center]" % hero_level)
	lines.append("")
	lines.append("[font_size=20][b]ARMAS[/b][/font_size]")

	var weapon_holder := _player.get_node_or_null("WeaponHolder") as Node2D
	var weapon_count := 0
	if weapon_holder:
		for weapon in weapon_holder.get_children():
			if not weapon.has_method("get_weapon_id"):
				continue
			var weapon_name := str(weapon.get_weapon_id()).capitalize()
			var weapon_icon: Texture2D
			if "weapon_data" in weapon:
				var weapon_data := weapon.weapon_data as WeaponData
				if weapon_data:
					weapon_name = weapon_data.display_name
					weapon_icon = weapon_data.icon
			var weapon_level: int = int(weapon.get_current_level()) if weapon.has_method("get_current_level") else 1
			lines.append(_format_inventory_line(weapon_icon, weapon_name, weapon_level))
			weapon_count += 1

	if weapon_count == 0:
		lines.append("Nenhuma arma adquirida.")

	lines.append("")
	lines.append("[font_size=20][b]RELÍQUIAS[/b][/font_size]")
	var relics := _upgrade_system.get_obtained_relics()
	if relics.is_empty():
		lines.append("Nenhuma relíquia adquirida.")
	else:
		for relic in relics:
			lines.append(_format_inventory_line(relic.icon, relic.display_name, 1))

	inventory_text.text = "\n".join(lines)


func _format_inventory_line(icon: Texture2D, item_name: String, item_level: int) -> String:
	var icon_markup := ""
	if icon and not icon.resource_path.is_empty():
		icon_markup = "[img=40x40]%s[/img] " % icon.resource_path
	return "%s%s — Nível %d" % [icon_markup, item_name, item_level]


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
