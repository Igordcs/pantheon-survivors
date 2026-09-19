extends Control
## Shop — Loja de personagens, armas e itens permanentes.

const PIXEL_FONT := preload("res://assets/fonts/press_start_2p.tres")

## Cor da borda do card conforme o estado do produto.
const ACCENT_AVAILABLE := Color(1.0, 0.82, 0.3)
const ACCENT_TOO_EXPENSIVE := Color(0.62, 0.3, 0.28)
const ACCENT_OWNED := Color(0.55, 0.85, 0.55)
const ACCENT_EQUIPPED := Color(0.45, 0.72, 0.95)

@onready var currency_label: Label = $Layout/Header/CurrencyPanel/CurrencyRow/CurrencyLabel
@onready var products_container: VBoxContainer = $Layout/Scroll/Products
@onready var empty_label: Label = $Layout/EmptyLabel
@onready var feedback_label: Label = $Layout/FeedbackLabel
@onready var characters_button: Button = $Layout/Tabs/CharactersButton
@onready var weapons_button: Button = $Layout/Tabs/WeaponsButton
@onready var items_button: Button = $Layout/Tabs/ItemsButton
@onready var back_button: Button = $Layout/BackButton
@onready var loadout_label: Label = $Layout/LoadoutLabel

var _category := ShopItemData.Category.CHARACTER


func _ready() -> void:
	MusicManager.play_menu_music()
	for tab in [characters_button, weapons_button, items_button]:
		_style_tab(tab)
	characters_button.pressed.connect(_show_category.bind(ShopItemData.Category.CHARACTER))
	weapons_button.pressed.connect(_show_category.bind(ShopItemData.Category.WEAPON))
	items_button.pressed.connect(_show_category.bind(ShopItemData.Category.ITEM))
	back_button.pressed.connect(_go_back)
	SaveManager.currency_changed.connect(_on_currency_changed)
	_update_currency()
	_update_loadout_label()
	_show_category(_category)
	characters_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _show_category(category: int) -> void:
	_category = category
	_update_loadout_label()
	characters_button.button_pressed = category == ShopItemData.Category.CHARACTER
	weapons_button.button_pressed = category == ShopItemData.Category.WEAPON
	items_button.button_pressed = category == ShopItemData.Category.ITEM
	feedback_label.text = ""
	for child in products_container.get_children():
		child.queue_free()
	var products := ShopCatalog.get_products(category)
	empty_label.visible = products.is_empty()
	for product in products:
		products_container.add_child(_create_product_card(product))
	_configure_vertical_focus()


func _create_product_card(product: ShopItemData) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Card_%s" % product.id
	panel.custom_minimum_size = Vector2(0, 104)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72, 72)
	# Pixel art borra com filtro linear.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = product.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 8)
	row.add_child(text_box)

	var title := Label.new()
	title.name = "ProductName"
	title.text = PixelText.fit(product.display_name)
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(title)

	var description := Label.new()
	description.text = product.description
	description.add_theme_font_override("font", PIXEL_FONT)
	description.add_theme_font_size_override("font_size", 9)
	description.add_theme_color_override("font_color", Color(0.85, 0.83, 0.89))
	description.add_theme_constant_override("line_spacing", 6)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(description)

	var button := Button.new()
	button.custom_minimum_size = Vector2(190, 52)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.set_meta("product", product)
	button.pressed.connect(_purchase.bind(product))
	_style_button(button)
	row.add_child(button)
	_update_purchase_button(button, product)
	_style_card(panel, product)
	return panel


## Aba ativa acende em dourado; as outras ficam apagadas.
func _style_tab(tab: Button) -> void:
	tab.add_theme_font_override("font", PIXEL_FONT)
	tab.add_theme_font_size_override("font_size", 12)
	tab.add_theme_color_override("font_color", Color(0.78, 0.75, 0.84))
	tab.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.35))
	tab.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
	tab.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.4))
	tab.add_theme_stylebox_override("normal", _panel_style(Color(0.28, 0.24, 0.36), false))
	tab.add_theme_stylebox_override("hover", _panel_style(ACCENT_AVAILABLE, false))
	# Só a aba ativa recebe o fundo âmbar; o foco é apenas uma borda clara.
	tab.add_theme_stylebox_override("focus", _panel_style(Color(0.62, 0.58, 0.72), false))
	tab.add_theme_stylebox_override("pressed", _panel_style(ACCENT_AVAILABLE, true))


func _style_button(button: Button) -> void:
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.4))
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.3, 0.25, 0.4), false))
	button.add_theme_stylebox_override("hover", _panel_style(ACCENT_AVAILABLE, true))
	button.add_theme_stylebox_override("focus", _panel_style(ACCENT_AVAILABLE, true))
	button.add_theme_stylebox_override("pressed", _panel_style(ACCENT_AVAILABLE, true))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.22, 0.2, 0.26), false))


## A borda do card diz de relance se da para comprar, se ja e seu ou se esta equipado.
func _style_card(panel: PanelContainer, product: ShopItemData) -> void:
	var accent := ACCENT_AVAILABLE
	if SaveManager.is_unlocked(_category_name(product.category), product.id):
		accent = ACCENT_OWNED
		if product.category == ShopItemData.Category.ITEM \
				and product.id in SaveManager.get_equipped_items():
			accent = ACCENT_EQUIPPED
	elif not SaveManager.can_afford(product.price):
		accent = ACCENT_TOO_EXPENSIVE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.86)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = accent
	style.content_margin_left = 18.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)


func _panel_style(border: Color, highlight: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.14, 0.05, 0.95) if highlight else Color(0.08, 0.06, 0.12, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	if highlight:
		style.shadow_color = Color(1, 0.6, 0, 0.35)
		style.shadow_size = 6
	return style


func _purchase(product: ShopItemData) -> void:
	MusicManager.play_ui_click()
	if product.category == ShopItemData.Category.ITEM and SaveManager.is_unlocked(&"item", product.id):
		if product.id in SaveManager.get_equipped_items():
			SaveManager.unequip_item(product.id)
			feedback_label.text = "%s removido do loadout." % product.display_name
		elif SaveManager.equip_item(product.id):
			feedback_label.text = "%s equipado." % product.display_name
		else:
			feedback_label.text = "Os três slots já estão ocupados. Remova um item primeiro."
		_update_loadout_label()
		_refresh_buttons()
		return
	if SaveManager.try_purchase(product):
		feedback_label.text = "%s adquirido!" % product.display_name
	else:
		feedback_label.text = "Moedas insuficientes ou conteúdo já adquirido."
	_update_currency()
	_update_loadout_label()
	_refresh_buttons()


func _refresh_buttons() -> void:
	for panel in products_container.get_children():
		var row := panel.get_child(0)
		for child in row.get_children():
			if child is Button and child.has_meta("product"):
				var product := child.get_meta("product") as ShopItemData
				_update_purchase_button(child, product)
				_style_card(panel as PanelContainer, product)


func _configure_vertical_focus() -> void:
	var purchase_buttons: Array[Button] = []
	for panel in products_container.get_children():
		for child in panel.get_child(0).get_children():
			if child is Button:
				purchase_buttons.append(child)
	var tabs: Array[Button] = [characters_button, weapons_button, items_button]
	var first_target: Control = purchase_buttons[0] if not purchase_buttons.is_empty() else back_button
	for tab in tabs:
		tab.focus_neighbor_bottom = tab.get_path_to(first_target)
	for index in purchase_buttons.size():
		var button := purchase_buttons[index]
		var previous: Control = characters_button if index == 0 else purchase_buttons[index - 1]
		var next: Control = back_button if index == purchase_buttons.size() - 1 else purchase_buttons[index + 1]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
	back_button.focus_neighbor_top = back_button.get_path_to(
		purchase_buttons.back() if not purchase_buttons.is_empty() else characters_button
	)


func _update_purchase_button(button: Button, product: ShopItemData) -> void:
	var category := _category_name(product.category)
	if SaveManager.is_unlocked(category, product.id):
		if product.category == ShopItemData.Category.ITEM:
			button.text = "REMOVER" if product.id in SaveManager.get_equipped_items() else "EQUIPAR"
			button.disabled = false
		else:
			button.text = "ADQUIRIDO"
			button.disabled = true
		button.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.65))
	else:
		button.text = "COMPRAR\n%d" % product.price
		button.disabled = not SaveManager.can_afford(product.price)
		button.add_theme_color_override(
			"font_disabled_color",
			Color(1.0, 0.35, 0.25) if button.disabled else Color.WHITE
		)


func _update_loadout_label() -> void:
	var names: Array[String] = []
	for id in SaveManager.get_equipped_items():
		var item := ItemCatalog.get_item(id)
		if item: names.append(PixelText.fit(item.display_name))
	while names.size() < 3: names.append("vazio")
	loadout_label.text = "EQUIPADOS:   %s   |   %s   |   %s" % names
	loadout_label.visible = _category == ShopItemData.Category.ITEM


func _on_currency_changed(_balance: int) -> void:
	_update_currency()
	_refresh_buttons()


func _update_currency() -> void:
	currency_label.text = "MOEDAS: %d" % SaveManager.get_currency()


func _category_name(category: int) -> StringName:
	match category:
		ShopItemData.Category.CHARACTER: return &"character"
		ShopItemData.Category.WEAPON: return &"weapon"
		ShopItemData.Category.ITEM: return &"item"
	return &""


func _go_back() -> void:
	MusicManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
