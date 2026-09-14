extends CanvasLayer
## Runtime sandbox toolbox, initialized only for development runs.

var _game: Node2D
var _player
var _upgrade_system: UpgradeSystem
var _hud
var _character_select: OptionButton
var _weapon_select: OptionButton
var _item_select: OptionButton
var _enemy_select: OptionButton
var _boss_select: OptionButton
var _status: Label


func setup(game: Node2D, player: CharacterBody2D, upgrade_system: UpgradeSystem, hud: Control) -> void:
	_game = game
	_player = player
	_upgrade_system = upgrade_system
	_hud = hud
	_build_ui()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 52.0)
	panel.custom_minimum_size = Vector2(310.0, 0.0)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	var title := Label.new()
	title.text = "SANDBOX"
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	_character_select = _add_selector(box, ContentRegistry.get_character_options())
	_add_button(box, "Trocar personagem", _switch_character)
	_weapon_select = _add_selector(box, ContentRegistry.get_weapon_options())
	_add_button(box, "Adicionar / melhorar arma", _grant_weapon)
	var item_options := {}
	for item in ItemCatalog.get_all(): item_options[item.display_name] = item.id
	_item_select = _add_selector(box, item_options)
	_add_button(box, "Adicionar / melhorar item", _grant_item)
	_enemy_select = _add_selector(box, ContentRegistry.get_enemy_options())
	_add_button(box, "Spawnar inimigo", _spawn_enemy)
	_boss_select = _add_selector(box, ContentRegistry.get_boss_options())
	_add_button(box, "Spawnar boss", _spawn_boss)
	_add_button(box, "Curar personagem", _heal_player)
	_add_button(box, "Remover inimigos", _clear_enemies)
	_add_button(box, "Voltar ao menu", _return_to_menu)
	_status = Label.new()
	_status.text = "F2 fica desativado durante qualquer run."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)


func _add_selector(parent: VBoxContainer, values: Dictionary) -> OptionButton:
	var selector := OptionButton.new()
	for display_name in values:
		selector.add_item(display_name)
		selector.set_item_metadata(selector.item_count - 1, values[display_name])
	parent.add_child(selector)
	return selector


func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _switch_character() -> void:
	var id := _character_select.get_item_metadata(_character_select.selected) as StringName
	_player.debug_switch_character(id)
	_hud.clear_inventory_icons()
	for weapon in _player.get_node("WeaponHolder").get_children():
		if weapon.has_method("get_weapon_id"):
			var data := weapon.get("weapon_data") as WeaponData
			_hud.add_weapon_icon(weapon.get_weapon_id(), data.icon if data else null, data.display_name if data else "")
	_status.text = "Personagem alterado para %s." % _character_select.get_item_text(_character_select.selected)


func _grant_weapon() -> void:
	var id := _weapon_select.get_item_metadata(_weapon_select.selected) as StringName
	var data := ContentRegistry.get_weapon_data(id)
	if _upgrade_system.debug_grant_weapon(data):
		_hud.add_weapon_icon(data.id, data.icon, data.display_name)
		_status.text = "%s adicionada ou melhorada." % data.display_name
	else:
		_status.text = "Não foi possível adicionar a arma."


func _grant_item() -> void:
	var id := _item_select.get_item_metadata(_item_select.selected) as StringName
	var data := ItemCatalog.get_item(id)
	var controller := _player.get_node_or_null("ItemEffectController") as ItemEffectController
	_status.text = "%s adicionado ou melhorado." % data.display_name if controller and controller.debug_grant_item(data) else "Item já está no nível máximo."


func _spawn_enemy() -> void:
	var id := _enemy_select.get_item_metadata(_enemy_select.selected) as StringName
	var scene := ContentRegistry.get_enemy_scene(id)
	var data := ContentRegistry.get_enemy_data(id)
	if not scene or not data:
		_status.text = "Conteúdo de inimigo inválido."
		return
	var enemy := scene.instantiate() as CharacterBody2D
	enemy.set("enemy_data", data)
	_game.get_node("World/Enemies").add_child(enemy)
	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(enemy.queue_free)
	var spawn_position := _spawn_position(190.0)
	if enemy.has_method("reset"):
		enemy.reset(spawn_position)
	else:
		enemy.global_position = spawn_position
	_status.text = "%s spawnado." % _enemy_select.get_item_text(_enemy_select.selected)


func _spawn_boss() -> void:
	var id := _boss_select.get_item_metadata(_boss_select.selected) as StringName
	var scene := ContentRegistry.get_boss_scene(id)
	if not scene:
		_status.text = "Conteúdo de boss inválido."
		return
	var boss := scene.instantiate() as Node2D
	_game.get_node("World/Enemies").add_child(boss)
	boss.global_position = _spawn_position(300.0)
	_status.text = "%s spawnado." % _boss_select.get_item_text(_boss_select.selected)


func _spawn_position(distance: float) -> Vector2:
	return _player.global_position + Vector2.from_angle(randf() * TAU) * distance


func _heal_player() -> void:
	var health := _player.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.heal(health.max_health)
	_status.text = "Vida restaurada."


func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()
	_status.text = "Inimigos removidos."


func _return_to_menu() -> void:
	Global.sandbox_mode = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
