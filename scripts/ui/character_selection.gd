extends Control
## CharacterSelection — Tela para escolher o personagem antes da Run.

const PIXEL_FONT := preload("res://assets/fonts/press_start_2p.tres")
const BACKGROUND_ART_PATH := "res://assets/sprites/character_select_bg.png"
const BACKGROUND_FALLBACK_PATH := "res://assets/sprites/menu_bg_pixel.jpg"

const CONTENT_WIDTH := 1184.0
const CARD_SEPARATION := 24.0
const CARD_MIN_WIDTH := 120.0
const CARD_MAX_WIDTH := 200.0
const CARD_HEIGHT := 182.0
const PORTRAIT_SIZE := 128.0
const SMALL_PORTRAIT_SIZE := 96.0

## Tetos das barras, com folga sobre o maior valor do elenco atual (150 de vida, 220 de velocidade).
const HEALTH_BAR_MAX := 180.0
const SPEED_BAR_MAX := 240.0

const DEFAULT_ACCENT := Color(1.0, 0.82, 0.3)
## Cor de destaque por panteão, usada na borda do card escolhido.
const ACCENTS := {
	&"eirik": Color(0.42, 0.66, 0.95),
	&"neferu": Color(1.0, 0.78, 0.25),
	&"perseus": Color(0.55, 0.85, 0.55),
	&"arthur": Color(0.72, 0.78, 0.93),
	&"kratos": Color(0.9, 0.32, 0.26),
	&"punisher": Color(0.82, 0.82, 0.85),
}

## Juramento e ligação com o deus que concedeu a arma (docs/lore.md). Fica aqui, e não
## em CharacterData, para não precisar alterar os .tres existentes.
const OATHS := {
	&"eirik": {
		"patron": "Escolhido por Thor",
		"oath": "— Que o trovão me encontre de pé.",
	},
	&"neferu": {
		"patron": "Escolhida por Rá",
		"oath": "— Enquanto houver luz, a Fenda não avança.",
	},
	&"perseus": {
		"patron": "Escolhido por Atena",
		"oath": "— O terror dos monstros será a minha arma.",
	},
	&"arthur": {
		"patron": "Portador de Excalibur",
		"oath": "— Camelot responde ao chamado do Véu.",
	},
	&"kratos": {
		"patron": "O Fantasma de Esparta",
		"oath": "— A guerra atravessou o Véu comigo.",
	},
	&"punisher": {
		"patron": "Sem deus, sem trégua",
		"oath": "— Nenhuma criatura da Fenda merece piedade.",
	},
}

@onready var background_art: TextureRect = $BackgroundArt
@onready var card_row: HBoxContainer = $Layout/CardRow
@onready var start_button: Button = $Layout/ButtonsContainer/StartButton
@onready var back_button: Button = $Layout/ButtonsContainer/BackButton
@onready var name_label: Label = $Layout/DetailsContainer/IdentityPanel/Identity/NameLabel
@onready var patron_label: Label = $Layout/DetailsContainer/IdentityPanel/Identity/PatronLabel
@onready var oath_label: Label = $Layout/DetailsContainer/IdentityPanel/Identity/OathLabel
@onready var info_label: Label = $Layout/DetailsContainer/IdentityPanel/Identity/InfoLabel
@onready var weapon_icon: TextureRect = $Layout/DetailsContainer/LoadoutPanel/Loadout/WeaponRow/WeaponIcon
@onready var weapon_name: Label = $Layout/DetailsContainer/LoadoutPanel/Loadout/WeaponRow/WeaponInfo/WeaponName
@onready var weapon_text: Label = $Layout/DetailsContainer/LoadoutPanel/Loadout/WeaponRow/WeaponInfo/WeaponText
@onready var health_label: Label = $Layout/DetailsContainer/LoadoutPanel/Loadout/StatsContainer/HealthRow/HealthLabel
@onready var health_bar: ProgressBar = $Layout/DetailsContainer/LoadoutPanel/Loadout/StatsContainer/HealthRow/HealthBar
@onready var speed_label: Label = $Layout/DetailsContainer/LoadoutPanel/Loadout/StatsContainer/SpeedRow/SpeedLabel
@onready var speed_bar: ProgressBar = $Layout/DetailsContainer/LoadoutPanel/Loadout/StatsContainer/SpeedRow/SpeedBar
@onready var items_label: Label = $Layout/DetailsContainer/LoadoutPanel/Loadout/ItemsLabel

var _unlocked_chars: Array = []
var _characters: Array[CharacterData] = []
var _cards: Array[Button] = []
var _selected_index := -1


func _ready() -> void:
	MusicManager.play_menu_music()
	_apply_background()

	start_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_start_pressed()
	)

	back_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_back_pressed()
	)

	_load_characters()


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


## Usa a arte dedicada da tela quando ela existir; até lá, reaproveita o fundo do menu.
func _apply_background() -> void:
	var texture: Texture2D = null
	if ResourceLoader.exists(BACKGROUND_ART_PATH):
		texture = ResourceLoader.load(BACKGROUND_ART_PATH) as Texture2D
	if texture == null:
		if ResourceLoader.exists(BACKGROUND_FALLBACK_PATH):
			texture = ResourceLoader.load(BACKGROUND_FALLBACK_PATH) as Texture2D
		push_warning(
			"CharacterSelection: arte \"%s\" ausente; usando o fundo do menu." % BACKGROUND_ART_PATH
		)
	background_art.texture = texture
	background_art.visible = texture != null


func _load_characters() -> void:
	_unlocked_chars = SaveManager.save_data.get("unlocked_characters", [])
	_characters.clear()

	for char_id in _unlocked_chars:
		var data := ContentRegistry.get_character_data(StringName(char_id))
		if data:
			_characters.append(data)

	_build_cards()

	if _characters.is_empty():
		start_button.disabled = true
		return
	_select_character(0, false)
	_cards[0].grab_focus()


func _build_cards() -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()

	var count := _characters.size()
	if count == 0:
		return

	var available := CONTENT_WIDTH - CARD_SEPARATION * float(count - 1)
	var card_width := clampf(floorf(available / float(count)), CARD_MIN_WIDTH, CARD_MAX_WIDTH)
	var portrait_size := PORTRAIT_SIZE if card_width >= PORTRAIT_SIZE + 24.0 else SMALL_PORTRAIT_SIZE

	for index in range(count):
		var data := _characters[index]
		var card := Button.new()
		card.name = "Card%d" % index
		card.custom_minimum_size = Vector2(card_width, CARD_HEIGHT)
		card.focus_mode = Control.FOCUS_ALL
		card.pressed.connect(_select_character.bind(index, true))

		var content := VBoxContainer.new()
		content.name = "Content"
		content.anchor_right = 1.0
		content.anchor_bottom = 1.0
		content.offset_left = 10.0
		content.offset_top = 10.0
		content.offset_right = -10.0
		content.offset_bottom = -10.0
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 8)
		card.add_child(content)

		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.texture = data.portrait
		# Pixel art precisa de filtro nearest; sem isso o retrato 64x64 sai borrado.
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(portrait)

		var label := Label.new()
		label.name = "CardName"
		label.text = _short_name(data.display_name)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", PIXEL_FONT)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		content.add_child(label)

		card_row.add_child(card)
		_cards.append(card)

	_refresh_card_styles()


## O card mostra só o primeiro nome; o nome completo aparece no painel de identidade.
func _short_name(display_name: String) -> String:
	var short := display_name.split(",")[0].strip_edges()
	return short.to_upper() if not short.is_empty() else display_name.to_upper()


func _accent_for(char_id: StringName) -> Color:
	return ACCENTS.get(char_id, DEFAULT_ACCENT)


func _refresh_card_styles() -> void:
	for index in range(_cards.size()):
		var accent := _accent_for(_characters[index].id)
		var selected := index == _selected_index
		var card := _cards[index]
		card.add_theme_stylebox_override("normal", _make_card_style(accent, selected))
		card.add_theme_stylebox_override("hover", _make_card_style(accent, true))
		card.add_theme_stylebox_override("pressed", _make_card_style(accent, true))
		card.add_theme_stylebox_override("focus", _make_card_style(accent, true))
		var label := card.get_node_or_null("Content/CardName") as Label
		if label:
			label.add_theme_color_override("font_color", accent if selected else Color(0.72, 0.7, 0.78))


func _make_card_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.08, 0.16, 0.92) if selected else Color(0.06, 0.05, 0.1, 0.82)
	var border := 3 if selected else 2
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.border_color = accent if selected else Color(0.26, 0.22, 0.34, 1.0)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	if selected:
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
		style.shadow_size = 8
	return style


func _select_relative_character(step: int) -> void:
	if _characters.is_empty():
		return
	var next_index := wrapi(_selected_index + step, 0, _characters.size())
	_select_character(next_index, true)
	_cards[next_index].grab_focus()


func _select_character(index: int, play_sound: bool = true) -> void:
	if index < 0 or index >= _characters.size() or index == _selected_index:
		return
	_selected_index = index
	if play_sound:
		MusicManager.play_ui_click()
	_refresh_card_styles()
	_update_character_details(index)


func _update_character_details(index: int) -> void:
	var data := _characters[index]
	var char_id := data.id
	Global.selected_character_id = char_id

	var accent := _accent_for(char_id)
	name_label.text = PixelText.fit(data.display_name)
	name_label.add_theme_color_override("font_color", accent)

	var lore: Dictionary = OATHS.get(char_id, {})
	patron_label.text = String(lore.get("patron", ""))
	patron_label.visible = not patron_label.text.is_empty()
	oath_label.text = String(lore.get("oath", ""))
	oath_label.visible = not oath_label.text.is_empty()
	info_label.text = "%s\n\nPerfil: %s" % [data.description, data.passive_description]

	var weapon_display := "Nenhuma"
	var weapon_description := "Sem arma inicial."
	var starting_weapon_icon: Texture2D
	if data.starting_weapon is WeaponData:
		weapon_display = data.starting_weapon.display_name
		weapon_description = data.starting_weapon.description
		starting_weapon_icon = data.starting_weapon.icon
	if char_id == &"punisher":
		var grenade_data := ContentRegistry.get_weapon_data(&"punisher_grenade")
		if grenade_data:
			weapon_display = "%s + %s" % [weapon_display, grenade_data.display_name]
			weapon_description = "As duas armas exclusivas acompanham o Justiceiro."
	weapon_icon.texture = starting_weapon_icon
	weapon_icon.visible = starting_weapon_icon != null
	weapon_name.text = PixelText.fit(weapon_display)
	weapon_text.text = weapon_description

	health_label.text = "VIDA %d" % int(data.base_health)
	health_bar.max_value = maxf(HEALTH_BAR_MAX, data.base_health)
	health_bar.value = data.base_health
	speed_label.text = "VELOCIDADE %d" % int(data.base_speed)
	speed_bar.max_value = maxf(SPEED_BAR_MAX, data.base_speed)
	speed_bar.value = data.base_speed

	var equipped_names: Array[String] = []
	for item_id in SaveManager.get_equipped_items():
		var equipped_item := ItemCatalog.get_item(item_id)
		if equipped_item:
			equipped_names.append(equipped_item.display_name)
	items_label.text = "Itens: %s" % (
		", ".join(equipped_names) if not equipped_names.is_empty() else "Nenhum"
	)

	start_button.disabled = false


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/phase_selection.tscn")
