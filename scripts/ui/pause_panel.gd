extends Control
## PausePanel — pausa a run e apresenta os itens obtidos e seus níveis.

## A fonte pixelada nao tem maiuscula acentuada propria, entao os titulos vao sem acento.
const GOLD := "ffe054"
const DIM := "b8b0c6"

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
	lines.append("[center][color=%s]NÍVEL DO HERÓI  %d[/color][/center]" % [GOLD, hero_level])
	lines.append("")
	lines.append(_section("ARMAS"))

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
		lines.append("[color=%s]Nenhuma arma adquirida.[/color]" % DIM)

	lines.append("")
	lines.append(_section("ITENS ATIVOS"))
	var item_controller := _player.get_node_or_null("ItemEffectController") as ItemEffectController
	var active_items := item_controller.get_active_items() if item_controller else []
	if active_items.is_empty():
		lines.append("[color=%s]Nenhum item ativo.[/color]" % DIM)
	else:
		for item in active_items:
			var item_level := item_controller.get_item_level(item.id)
			lines.append(_format_inventory_line(item.icon, item.display_name, item_level))

	inventory_text.text = PixelText.fit("\n".join(lines))


func _section(title: String) -> String:
	return "[font_size=13][color=%s]%s[/color][/font_size]" % [GOLD, title]


func _format_inventory_line(icon: Texture2D, item_name: String, item_level: int) -> String:
	var icon_markup := ""
	if icon and not icon.resource_path.is_empty():
		icon_markup = "[img=28x28]%s[/img]  " % icon.resource_path
	return "%s%s  [color=%s]Nv %d[/color]" % [
		icon_markup, PixelText.fit(item_name), GOLD, item_level,
	]


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
