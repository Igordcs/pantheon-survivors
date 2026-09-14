extends CanvasLayer
## Global developer tools: F2 or Ctrl+D open the dev menu, F3 shows performance.

@onready var label: Label = $MarginContainer/VBoxContainer/StatsLabel

var _dev_overlay: ColorRect
var _character_select: OptionButton
var _map_select: OptionButton
var _was_paused := false

## Teclas de funcao viram atalho de sistema em muito notebook, entao o menu dev
## tambem responde a uma combinacao que nao depende delas.
const DEV_MENU_KEYS := [KEY_F2, KEY_F9]

const CHARACTERS := [
	["Eirik", &"eirik"], ["Arthur", &"arthur"], ["Neferu", &"neferu"],
	["Perseus", &"perseus"], ["Justiceiro", &"punisher"], ["Kratos", &"kratos"],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$MarginContainer.hide()
	_build_dev_menu()


func _input(event: InputEvent) -> void:
	if _is_dev_menu_shortcut(event):
		if _dev_overlay.visible or _can_open_dev_menu():
			_toggle_dev_menu()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("debug_f3") or (event is InputEventKey and event.keycode == KEY_F3 and event.pressed):
		$MarginContainer.visible = not $MarginContainer.visible


func _is_dev_menu_shortcut(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if event.keycode in DEV_MENU_KEYS:
		return true
	return event.ctrl_pressed and event.keycode == KEY_D


func _process(_delta: float) -> void:
	if not $MarginContainer.visible:
		return
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	label.text = "FPS: %d\nObjects: %d\nDraw Calls: %d" % [fps, objects, draw_calls]


func _build_dev_menu() -> void:
	_dev_overlay = ColorRect.new()
	_dev_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dev_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	_dev_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dev_overlay.hide()
	add_child(_dev_overlay)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430.0, 350.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-215.0, -175.0)
	_dev_overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "MODO DE DESENVOLVIMENTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.22))
	box.add_child(title)
	var help := Label.new()
	help.text = "Este modo não altera moedas ou conquistas."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	_character_select = OptionButton.new()
	for entry in CHARACTERS:
		_character_select.add_item(entry[0])
		_character_select.set_item_metadata(_character_select.item_count - 1, entry[1])
	box.add_child(_character_select)
	_map_select = OptionButton.new()
	for map_data in MapCatalog.get_maps():
		_map_select.add_item(map_data.display_name)
		_map_select.set_item_metadata(_map_select.item_count - 1, map_data.map_id)
		if map_data.map_id == Global.selected_map_id:
			_map_select.select(_map_select.item_count - 1)
	box.add_child(_map_select)
	var start := Button.new()
	start.text = "INICIAR MUNDO"
	start.custom_minimum_size.y = 48.0
	start.pressed.connect(_start_sandbox)
	box.add_child(start)
	var close := Button.new()
	close.text = "Fechar (F2 ou Ctrl+D)"
	close.pressed.connect(_toggle_dev_menu)
	box.add_child(close)


func _toggle_dev_menu() -> void:
	if _dev_overlay.visible:
		_dev_overlay.hide()
		get_tree().paused = _was_paused
	else:
		_was_paused = get_tree().paused
		_dev_overlay.show()
		get_tree().paused = true


func _can_open_dev_menu() -> bool:
	var current_scene := get_tree().current_scene
	if not current_scene:
		return false
	return current_scene.scene_file_path != "res://scenes/game/game.tscn"


func _start_sandbox() -> void:
	Global.selected_character_id = _character_select.get_item_metadata(_character_select.selected) as StringName
	if _map_select.selected >= 0:
		Global.selected_map_id = _map_select.get_item_metadata(_map_select.selected) as StringName
	Global.sandbox_mode = true
	_dev_overlay.hide()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
