extends Control
## PhaseSelection — Escolha da ruptura antes de montar o herói.

const PIXEL_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const CHARACTER_SELECTION_SCENE := "res://scenes/ui/character_selection.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const BACKGROUND_ART_PATH := "res://assets/sprites/character_select_bg.png"
const BACKGROUND_FALLBACK_PATH := "res://assets/sprites/menu_bg_pixel.jpg"

const CONTENT_WIDTH := 1184.0
const CARD_SEPARATION := 28.0
const CARD_MIN_WIDTH := 200.0
const CARD_MAX_WIDTH := 320.0
const CARD_HEIGHT := 230.0

const LOCKED_ACCENT := Color(0.42, 0.4, 0.48)

@onready var background_art: TextureRect = $BackgroundArt
@onready var card_row: HBoxContainer = $Layout/CardRow
@onready var name_label: Label = $Layout/DetailsPanel/Details/NameLabel
@onready var status_label: Label = $Layout/DetailsPanel/Details/StatusLabel
@onready var description_label: Label = $Layout/DetailsPanel/Details/DescriptionLabel
@onready var anchors_label: Label = $Layout/DetailsPanel/Details/AnchorsLabel
@onready var start_button: Button = $Layout/ButtonsContainer/StartButton
@onready var back_button: Button = $Layout/ButtonsContainer/BackButton

var _phases: Array[PhaseData] = []
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

	_load_phases()


func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return
	if event is InputEventKey and event.echo:
		return

	var step := 0
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		step = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		step = 1

	if step != 0:
		_select_relative(step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not start_button.disabled:
		get_viewport().set_input_as_handled()
		_on_start_pressed()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _apply_background() -> void:
	var texture: Texture2D = null
	if ResourceLoader.exists(BACKGROUND_ART_PATH):
		texture = ResourceLoader.load(BACKGROUND_ART_PATH) as Texture2D
	if texture == null and ResourceLoader.exists(BACKGROUND_FALLBACK_PATH):
		texture = ResourceLoader.load(BACKGROUND_FALLBACK_PATH) as Texture2D
	background_art.texture = texture
	background_art.visible = texture != null


func _load_phases() -> void:
	_phases = PhaseCatalog.get_phases()
	_build_cards()
	if _phases.is_empty():
		start_button.disabled = true
		return
	# Abre já na fase mais avançada que o jogador pode jogar.
	var latest := SaveManager.get_latest_unlocked_phase()
	var index := maxi(PhaseCatalog.get_phase_index(latest), 0)
	_select_phase(index, false)
	_cards[index].grab_focus()


func _build_cards() -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()

	var count := _phases.size()
	if count == 0:
		return
	var available := CONTENT_WIDTH - CARD_SEPARATION * float(count - 1)
	var card_width := clampf(floorf(available / float(count)), CARD_MIN_WIDTH, CARD_MAX_WIDTH)

	for index in range(count):
		var phase := _phases[index]
		var unlocked := SaveManager.is_phase_unlocked(phase.phase_id)
		var card := Button.new()
		card.name = "PhaseCard%d" % index
		card.custom_minimum_size = Vector2(card_width, CARD_HEIGHT)
		card.focus_mode = Control.FOCUS_ALL
		card.pressed.connect(_select_phase.bind(index, true))

		var box := VBoxContainer.new()
		box.name = "Content"
		box.anchor_right = 1.0
		box.anchor_bottom = 1.0
		box.offset_left = 14.0
		box.offset_top = 14.0
		box.offset_right = -14.0
		box.offset_bottom = -14.0
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 10)
		card.add_child(box)

		box.add_child(_card_label("Order", "FASE %d" % phase.order, 10,
			Color(0.66, 0.63, 0.74)))
		box.add_child(_card_label("Name", PixelText.upper(phase.display_name), 13,
			phase.accent_color if unlocked else LOCKED_ACCENT, true))
		box.add_child(_card_label("Anchors", _anchors_summary(phase), 9,
			Color(0.78, 0.76, 0.84)))
		box.add_child(_card_label("Status", _status_text(phase), 10,
			_status_color(phase), true))

		card_row.add_child(card)
		_cards.append(card)

	_refresh_card_styles()


func _card_label(node_name: String, text: String, size: int, color: Color,
		wrap: bool = false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("line_spacing", 6)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _anchors_summary(phase: PhaseData) -> String:
	var count := phase.get_anchor_count()
	return "%d ANCORA" % count if count == 1 else "%d ANCORAS" % count


func _status_text(phase: PhaseData) -> String:
	if not SaveManager.is_phase_unlocked(phase.phase_id):
		return "TRANCADA"
	if SaveManager.is_phase_completed(phase.phase_id):
		return "SELADA"
	return "ABERTA"


func _status_color(phase: PhaseData) -> Color:
	if not SaveManager.is_phase_unlocked(phase.phase_id):
		return LOCKED_ACCENT
	if SaveManager.is_phase_completed(phase.phase_id):
		return Color(0.55, 0.85, 0.55)
	return Color(1.0, 0.82, 0.3)


func _refresh_card_styles() -> void:
	for index in range(_cards.size()):
		var phase := _phases[index]
		var unlocked := SaveManager.is_phase_unlocked(phase.phase_id)
		var accent := phase.accent_color if unlocked else LOCKED_ACCENT
		var selected := index == _selected_index
		var card := _cards[index]
		card.add_theme_stylebox_override("normal", _make_card_style(accent, selected, unlocked))
		card.add_theme_stylebox_override("hover", _make_card_style(accent, true, unlocked))
		card.add_theme_stylebox_override("pressed", _make_card_style(accent, true, unlocked))
		card.add_theme_stylebox_override("focus", _make_card_style(accent, true, unlocked))


func _make_card_style(accent: Color, selected: bool, unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if unlocked:
		style.bg_color = Color(0.11, 0.08, 0.16, 0.92) if selected else Color(0.06, 0.05, 0.1, 0.82)
	else:
		style.bg_color = Color(0.05, 0.05, 0.07, 0.78)
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
	if selected and unlocked:
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
		style.shadow_size = 8
	return style


func _select_relative(step: int) -> void:
	if _phases.is_empty():
		return
	var next_index := wrapi(_selected_index + step, 0, _phases.size())
	_select_phase(next_index, true)
	_cards[next_index].grab_focus()


func _select_phase(index: int, play_sound: bool = true) -> void:
	if index < 0 or index >= _phases.size() or index == _selected_index:
		return
	_selected_index = index
	if play_sound:
		MusicManager.play_ui_click()
	_refresh_card_styles()
	_update_details(index)


func _update_details(index: int) -> void:
	var phase := _phases[index]
	var unlocked := SaveManager.is_phase_unlocked(phase.phase_id)

	name_label.text = PixelText.fit(phase.display_name)
	name_label.add_theme_color_override("font_color",
		phase.accent_color if unlocked else LOCKED_ACCENT)
	status_label.text = _status_text(phase)
	status_label.add_theme_color_override("font_color", _status_color(phase))

	if unlocked:
		description_label.text = phase.description
		var names: Array[String] = []
		for anchor in phase.get_anchors():
			names.append(ContentRegistry.get_boss_display_name(anchor.boss_id))
		anchors_label.text = "Ancoras da Fenda: %s" % PixelText.fit(", ".join(names))
	else:
		var previous := _previous_phase_name(phase)
		description_label.text = "Esta ruptura ainda não foi detectada." if previous.is_empty() \
			else "Sele a ruptura de %s para que esta seja detectada." % previous
		anchors_label.text = "Âncoras desconhecidas."

	start_button.disabled = not unlocked
	start_button.text = "REVISITAR" if SaveManager.is_phase_completed(phase.phase_id) else "INICIAR"


func _previous_phase_name(phase: PhaseData) -> String:
	var index := PhaseCatalog.get_phase_index(phase.phase_id)
	if index <= 0:
		return ""
	return PhaseCatalog.get_phases()[index - 1].display_name


func _on_start_pressed() -> void:
	if _selected_index < 0:
		return
	var phase := _phases[_selected_index]
	if not SaveManager.is_phase_unlocked(phase.phase_id):
		return
	Global.selected_phase_id = phase.phase_id
	Global.selected_map_id = phase.map_id
	get_tree().change_scene_to_file(CHARACTER_SELECTION_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
