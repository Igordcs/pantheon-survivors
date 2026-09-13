extends Control
## CharacterSelection — Tela para escolher o personagem antes da Run.

const MAX_CHARACTER_COLUMNS := 4

@onready var character_list: ItemList = $VBoxContainer/ItemList
@onready var start_button: Button = $VBoxContainer/ButtonsContainer/StartButton
@onready var back_button: Button = $VBoxContainer/ButtonsContainer/BackButton
@onready var info_label: Label = $VBoxContainer/DetailsContainer/InfoLabel
@onready var weapon_icon: TextureRect = $VBoxContainer/DetailsContainer/WeaponRow/WeaponIcon
@onready var weapon_text: Label = $VBoxContainer/DetailsContainer/WeaponRow/WeaponText
@onready var health_label: Label = $VBoxContainer/DetailsContainer/StatsContainer/HealthLabel
@onready var speed_label: Label = $VBoxContainer/DetailsContainer/StatsContainer/SpeedLabel

var _unlocked_chars = []


func _ready() -> void:
	MusicManager.play_menu_music()
	
	start_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_start_pressed()
	)
	
	back_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_back_pressed()
	)
	
	character_list.item_selected.connect(_on_item_selected)
	
	_load_characters()
	character_list.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	if event is InputEventKey and event.echo:
		return

	var selection_step := 0
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		selection_step = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		selection_step = 1

	if selection_step != 0:
		_select_relative_character(selection_step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not start_button.disabled:
		get_viewport().set_input_as_handled()
		_on_start_pressed()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _load_characters() -> void:
	_unlocked_chars = SaveManager.save_data.get("unlocked_characters", [])
	character_list.clear()
	
	for char_id in _unlocked_chars:
		var data_path = "res://resources/characters/%s_data.tres" % char_id
		if ResourceLoader.exists(data_path):
			var data = load(data_path) as CharacterData
			if data:
				character_list.add_item(data.display_name, data.portrait)
				character_list.set_item_metadata(character_list.get_item_count() - 1, char_id)
				
	_center_character_columns()

	if character_list.get_item_count() > 0:
		character_list.select(0)
		_update_character_details(0)


## A ItemList encosta as colunas à esquerda quando sobra espaço. Ajustando a largura
## mínima ao número real de personagens, o SHRINK_CENTER da cena centraliza a fileira.
func _center_character_columns() -> void:
	var item_count := character_list.get_item_count()
	if item_count <= 0:
		return
	var columns := mini(item_count, MAX_CHARACTER_COLUMNS)
	character_list.max_columns = columns
	# O espaçamento entre colunas, as bordas do painel e a barra de rolagem também
	# ocupam largura; sem reservá-los, a última coluna quebra para uma segunda linha.
	var extra := float((columns - 1) * character_list.get_theme_constant("h_separation"))
	var panel := character_list.get_theme_stylebox("panel")
	if panel:
		extra += panel.get_margin(SIDE_LEFT) + panel.get_margin(SIDE_RIGHT)
	var scrollbar := character_list.get_v_scroll_bar()
	if scrollbar:
		extra += scrollbar.get_combined_minimum_size().x
	character_list.custom_minimum_size.x = columns * character_list.fixed_column_width + extra
	character_list.custom_minimum_size.y = _row_height()


## Altura exata de uma fileira. A altura fixa da cena sobrava abaixo da linha, e essa
## sobra aparecia como uma margem maior embaixo da caixa de seleção do personagem.
func _row_height() -> float:
	var height := float(character_list.fixed_icon_size.y)
	height += character_list.get_theme_constant("icon_margin")
	height += character_list.get_theme_constant("line_separation")
	height += character_list.get_theme_constant("v_separation")
	var font := character_list.get_theme_font("font")
	if font:
		height += font.get_height(character_list.get_theme_font_size("font_size"))
	var panel := character_list.get_theme_stylebox("panel")
	if panel:
		height += panel.get_margin(SIDE_TOP) + panel.get_margin(SIDE_BOTTOM)
	return height


func _select_relative_character(step: int) -> void:
	var item_count := character_list.get_item_count()
	if item_count == 0:
		return
	var selected_items := character_list.get_selected_items()
	var current_index := selected_items[0] if not selected_items.is_empty() else 0
	var next_index := wrapi(current_index + step, 0, item_count)
	character_list.select(next_index)
	character_list.ensure_current_is_visible()
	_on_item_selected(next_index)


func _on_item_selected(index: int) -> void:
	MusicManager.play_ui_click()
	_update_character_details(index)


func _update_character_details(index: int) -> void:
	var char_id = character_list.get_item_metadata(index) as StringName
	Global.selected_character_id = char_id
	
	var data_path = "res://resources/characters/%s_data.tres" % char_id
	var data = load(data_path) as CharacterData
	if data:
		var weapon_name := "Nenhuma"
		var weapon_description := "Sem arma inicial."
		var starting_weapon_icon: Texture2D
		if data.starting_weapon is WeaponData:
			weapon_name = data.starting_weapon.display_name
			weapon_description = data.starting_weapon.description
			starting_weapon_icon = data.starting_weapon.icon
		if char_id == &"punisher":
			var grenade_data := load("res://resources/weapons/punisher_grenade_data.tres") as WeaponData
			if grenade_data:
				weapon_name = "%s + %s" % [weapon_name, grenade_data.display_name]
				weapon_description = "As duas armas exclusivas acompanham o Justiceiro."

		info_label.text = "%s\n\nPerfil: %s" % [
			data.description,
			data.passive_description,
		]
		var equipped_names: Array[String] = []
		for item_id in SaveManager.get_equipped_items():
			var equipped_item := ItemCatalog.get_item(item_id)
			if equipped_item: equipped_names.append(equipped_item.display_name)
		info_label.text += "\n\nItens: %s" % (", ".join(equipped_names) if not equipped_names.is_empty() else "Nenhum")
		weapon_icon.texture = starting_weapon_icon
		weapon_icon.visible = starting_weapon_icon != null
		weapon_text.text = "Arma inicial: %s\n%s" % [weapon_name, weapon_description]
		health_label.text = "Vida: %d" % int(data.base_health)
		speed_label.text = "Velocidade: %d" % int(data.base_speed)
	
	start_button.disabled = false


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
