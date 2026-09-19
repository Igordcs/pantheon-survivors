extends Control
## LevelUpPanel — UI para escolhas de level up. Pausa o jogo enquanto ativa.

signal option_chosen(option: UpgradeOption)

const PIXEL_FONT := preload("res://assets/fonts/press_start_2p.tres")
const OPTION_ICON_SIZE: int = 56
const ACCENT := Color(1.0, 0.82, 0.3)

@onready var buttons_container: VBoxContainer = $Panel/Content/VBoxContainer
var _current_options: Array[UpgradeOption] = []
var _option_buttons: Array[Button] = []
var _selected_index: int = 0


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS # Continua rodando quando pausado


func _input(event: InputEvent) -> void:
	if not visible or _option_buttons.is_empty():
		return
	if event is InputEventKey and event.echo:
		return

	var selection_step := 0
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		selection_step = -1
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		selection_step = 1

	if selection_step != 0:
		_focus_option(_selected_index + selection_step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_button_pressed(_selected_index)


func show_options(options: Array[UpgradeOption]) -> void:
	if options.is_empty():
		return
		
	_current_options = options
	_option_buttons.clear()
	_selected_index = 0
	
	# Limpar botões antigos
	for child in buttons_container.get_children():
		child.queue_free()
		
	# Criar novos botões
	for i in range(options.size()):
		var btn := _create_option_card(options[i])
		btn.pressed.connect(_on_button_pressed.bind(i))
		btn.focus_entered.connect(_on_button_focused.bind(i))
		buttons_container.add_child(btn)
		_option_buttons.append(btn)
		
	show()
	get_tree().paused = true
	_focus_option(0)


## Cada dádiva vira um card: o que os deuses enviam, o nome e o que ela faz.
func _create_option_card(option: UpgradeOption) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 104)
	card.focus_mode = Control.FOCUS_ALL
	card.add_theme_stylebox_override("normal", _card_style(false))
	card.add_theme_stylebox_override("hover", _card_style(true))
	card.add_theme_stylebox_override("focus", _card_style(true))
	card.add_theme_stylebox_override("pressed", _card_style(true))

	var row := HBoxContainer.new()
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 16.0
	row.offset_top = 12.0
	row.offset_right = -16.0
	row.offset_bottom = -12.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var item_icon := _get_item_icon(option.item_data)
	if item_icon:
		var icon := TextureRect.new()
		icon.name = "OptionIcon"
		icon.texture = item_icon
		# Pixel art borra com filtro linear.
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(OPTION_ICON_SIZE, OPTION_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 6)
	row.add_child(text_box)

	if not option.kind_label.is_empty():
		text_box.add_child(_card_label(
			"Kind", PixelText.fit(option.kind_label), 8, Color(0.72, 0.68, 0.82)
		))
	text_box.add_child(_card_label(
		"OptionName", PixelText.fit(option.display_text), 12, ACCENT
	))
	if not option.description_text.is_empty():
		text_box.add_child(_card_label(
			"OptionDescription", PixelText.fit(option.description_text), 9,
			Color(0.85, 0.83, 0.89)
		))
	return card


func _card_label(node_name: String, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("line_spacing", 6)
	return label


## A dádiva em foco acende em dourado.
func _card_style(highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.05, 0.95) if highlight else Color(0.08, 0.06, 0.12, 0.85)
	var border := 3 if highlight else 2
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.border_color = ACCENT if highlight else Color(0.3, 0.25, 0.4)
	if highlight:
		style.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
		style.shadow_size = 8
	return style


func _get_item_icon(item_data: Resource) -> Texture2D:
	if item_data is WeaponData:
		return (item_data as WeaponData).icon
	if item_data is ItemData:
		return (item_data as ItemData).icon
	return null


func _focus_option(index: int) -> void:
	if _option_buttons.is_empty():
		return
	_selected_index = wrapi(index, 0, _option_buttons.size())
	var button := _option_buttons[_selected_index]
	if is_instance_valid(button):
		button.grab_focus()


func _on_button_focused(index: int) -> void:
	_selected_index = index


func _on_button_pressed(index: int) -> void:
	if index < 0 or index >= _current_options.size():
		return
		
	var chosen = _current_options[index]
	get_viewport().gui_release_focus()
	hide()
	get_tree().paused = false
	option_chosen.emit(chosen)
