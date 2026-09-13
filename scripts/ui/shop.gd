extends Control

@onready var currency_label: Label = $Margin/VBox/Header/CurrencyLabel
@onready var products_container: VBoxContainer = $Margin/VBox/Scroll/Products
@onready var empty_label: Label = $Margin/VBox/EmptyLabel
@onready var feedback_label: Label = $Margin/VBox/FeedbackLabel
@onready var characters_button: Button = $Margin/VBox/Tabs/CharactersButton
@onready var weapons_button: Button = $Margin/VBox/Tabs/WeaponsButton
@onready var items_button: Button = $Margin/VBox/Tabs/ItemsButton
@onready var back_button: Button = $Margin/VBox/BackButton

var _category := ShopItemData.Category.CHARACTER


func _ready() -> void:
	MusicManager.play_menu_music()
	characters_button.pressed.connect(_show_category.bind(ShopItemData.Category.CHARACTER))
	weapons_button.pressed.connect(_show_category.bind(ShopItemData.Category.WEAPON))
	items_button.pressed.connect(_show_category.bind(ShopItemData.Category.ITEM))
	back_button.pressed.connect(_go_back)
	SaveManager.currency_changed.connect(_on_currency_changed)
	_update_currency()
	_show_category(_category)
	characters_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _show_category(category: int) -> void:
	_category = category
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
	panel.custom_minimum_size = Vector2(0, 112)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(80, 80)
	icon.texture = product.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var description := Label.new()
	description.text = "%s\n%s" % [product.display_name, product.description]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(description)

	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 48)
	button.set_meta("product", product)
	button.pressed.connect(_purchase.bind(product))
	row.add_child(button)
	_update_purchase_button(button, product)
	return panel


func _purchase(product: ShopItemData) -> void:
	MusicManager.play_ui_click()
	if SaveManager.try_purchase(product):
		feedback_label.text = "%s adquirido!" % product.display_name
	else:
		feedback_label.text = "Moedas insuficientes ou conteúdo já adquirido."
	_update_currency()
	_refresh_buttons()


func _refresh_buttons() -> void:
	for panel in products_container.get_children():
		var row := panel.get_child(0)
		for child in row.get_children():
			if child is Button and child.has_meta("product"):
				_update_purchase_button(child, child.get_meta("product") as ShopItemData)


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
		button.text = "ADQUIRIDO"
		button.disabled = true
		button.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.65))
	else:
		button.text = "COMPRAR\n%d moedas" % product.price
		button.disabled = not SaveManager.can_afford(product.price)
		button.add_theme_color_override(
			"font_disabled_color",
			Color(1.0, 0.35, 0.25) if button.disabled else Color.WHITE
		)


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
