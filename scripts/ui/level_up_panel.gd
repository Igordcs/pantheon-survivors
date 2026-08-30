extends Control
## LevelUpPanel — UI para escolhas de level up. Pausa o jogo enquanto ativa.

signal option_chosen(option: UpgradeOption)

const OPTION_ICON_SIZE: int = 64

@onready var buttons_container: VBoxContainer = $Panel/VBoxContainer
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
		var opt := options[i]
		var btn := Button.new()
		btn.text = opt.display_text
		if not opt.description_text.is_empty():
			btn.text += "\n%s" % opt.description_text
		btn.custom_minimum_size = Vector2(0, 90)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var item_icon := _get_item_icon(opt.item_data)
		if item_icon:
			btn.icon = item_icon
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", OPTION_ICON_SIZE)
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_button_pressed.bind(i))
		btn.focus_entered.connect(_on_button_focused.bind(i))
		buttons_container.add_child(btn)
		_option_buttons.append(btn)
		
	show()
	get_tree().paused = true
	_focus_option(0)


func _get_item_icon(item_data: Resource) -> Texture2D:
	if item_data is WeaponData:
		return (item_data as WeaponData).icon
	if item_data is RelicData:
		return (item_data as RelicData).icon
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
