extends Control
## HUD — Mostra as informações do player e da run na tela.

const PIXEL_FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

const ANCHOR_PIP_SIZE := Vector2(18, 18)
const ANCHOR_PENDING := Color(0.95, 0.82, 0.45)
const ANCHOR_FALLEN := Color(0.32, 0.28, 0.38)
const BOSS_BAR_FADE := 0.25

@onready var hp_bar: ProgressBar = $VBoxContainer/TopBar/HPBar
@onready var xp_bar: ProgressBar = $VBoxContainer/TopBar/XPBar
@onready var level_label: Label = $VBoxContainer/TopBar/LevelLabel

@onready var time_label: Label = $VBoxContainer/TopBar/TimeLabel
@onready var kills_label: Label = $VBoxContainer/TopBar/KillsLabel
@onready var coins_label: Label = $VBoxContainer/TopBar/CoinsLabel

@onready var weapons_container: HBoxContainer = $VBoxContainer/BottomBar/WeaponsContainer
@onready var boss_warning: Label = $BossWarning

@onready var anchor_panel: PanelContainer = $AnchorPanel
@onready var anchor_label: Label = $AnchorPanel/AnchorRow/AnchorLabel
@onready var anchor_pips: HBoxContainer = $AnchorPanel/AnchorRow/AnchorPips

@onready var boss_intro_panel: PanelContainer = $BossIntroPanel
@onready var boss_intro_epithet: Label = $BossIntroPanel/BossIntroBox/EpithetLabel
@onready var boss_intro_name: Label = $BossIntroPanel/BossIntroBox/NameLabel
@onready var boss_intro_lore: Label = $BossIntroPanel/BossIntroBox/LoreLabel

@onready var boss_panel: PanelContainer = $BossPanel
@onready var boss_name_label: Label = $BossPanel/BossBox/BossNameLabel
@onready var boss_bar: ProgressBar = $BossPanel/BossBox/BossBar
@onready var boss_hp_label: Label = $BossPanel/BossBox/BossHPLabel

var _kills: int = 0
var _announcement_tween: Tween
var _boss_tween: Tween
var _intro_tween: Tween
var _anchor_total: int = 0
var _anchor_defeated: int = 0


func _ready() -> void:
	boss_panel.hide()
	boss_panel.modulate.a = 0.0
	boss_intro_panel.hide()
	boss_intro_panel.modulate.a = 0.0
	anchor_panel.hide()


# --------------------------------------------------------------- Âncoras da fase

## Quantas Âncoras a ruptura tem e quantas já caíram (docs/lore.md).
func update_anchor_progress(defeated: int, total: int) -> void:
	_anchor_defeated = maxi(defeated, 0)
	_anchor_total = maxi(total, 0)
	if _anchor_total <= 0:
		anchor_panel.hide()
		return
	anchor_panel.show()
	var remaining := maxi(_anchor_total - _anchor_defeated, 0)
	anchor_label.text = "ANCORAS %d/%d" % [remaining, _anchor_total]
	_rebuild_anchor_pips()


func _rebuild_anchor_pips() -> void:
	for child in anchor_pips.get_children():
		child.free()
	for index in range(_anchor_total):
		var pip := Panel.new()
		pip.custom_minimum_size = ANCHOR_PIP_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override("panel", _make_pip_style(index >= _anchor_defeated))
		anchor_pips.add_child(pip)


## Âncora de pé fica acesa em dourado; Âncora derrubada apaga.
func _make_pip_style(pending: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.11, 0.06, 0.95) if pending else Color(0.07, 0.06, 0.09, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = ANCHOR_PENDING if pending else ANCHOR_FALLEN
	if pending:
		style.shadow_color = Color(ANCHOR_PENDING.r, ANCHOR_PENDING.g, ANCHOR_PENDING.b, 0.35)
		style.shadow_size = 4
	return style


# ------------------------------------------------------------ barra do chefe

func show_boss_bar(boss_name: String, maximum: float) -> void:
	boss_bar.max_value = maxf(maximum, 1.0)
	boss_bar.value = boss_bar.max_value
	boss_name_label.text = PixelText.upper(boss_name)
	_update_boss_hp_label(boss_bar.max_value, boss_bar.max_value)
	boss_panel.show()
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.tween_property(boss_panel, "modulate:a", 1.0, BOSS_BAR_FADE)


func update_boss_hp(current: float, maximum: float = 0.0) -> void:
	if maximum > 0.0:
		boss_bar.max_value = maximum
	boss_bar.value = clampf(current, 0.0, boss_bar.max_value)
	_update_boss_hp_label(boss_bar.value, boss_bar.max_value)


func hide_boss_bar() -> void:
	if not boss_panel.visible:
		return
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.tween_property(boss_panel, "modulate:a", 0.0, BOSS_BAR_FADE)
	_boss_tween.tween_callback(boss_panel.hide)


func _update_boss_hp_label(current: float, maximum: float) -> void:
	boss_hp_label.text = "%d / %d" % [ceili(current), ceili(maximum)]


# ------------------------------------------------------------------- avisos

## Apresenta a Âncora: quem é e por que ela sustenta a ruptura (docs/lore.md).
func show_boss_intro(display_name: String, epithet: String, lore: String,
		duration: float) -> void:
	var position_text := ""
	if _anchor_total > 1:
		position_text = "ANCORA %d DE %d  ·  " % [_anchor_defeated + 1, _anchor_total]
	boss_intro_epithet.text = position_text + PixelText.upper(epithet)
	boss_intro_epithet.visible = not boss_intro_epithet.text.strip_edges().is_empty()
	boss_intro_name.text = PixelText.upper(display_name)
	boss_intro_lore.text = PixelText.fit(lore)
	boss_intro_lore.visible = not lore.strip_edges().is_empty()

	boss_intro_panel.show()
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_property(boss_intro_panel, "modulate:a", 1.0, 0.35)
	_intro_tween.tween_interval(maxf(duration, 0.5))
	_intro_tween.tween_property(boss_intro_panel, "modulate:a", 0.0, 0.6)
	_intro_tween.tween_callback(boss_intro_panel.hide)


## Frase curta de abertura da fase e marcos da run.
func show_run_message(message: String, duration: float = 4.0) -> void:
	if not message.strip_edges().is_empty():
		_show_announcement(PixelText.fit(message), duration, Color(1.0, 0.82, 0.35))


func show_horde_event(message: String) -> void:
	if not message.is_empty():
		_show_announcement(message, 2.0, Color(1.0, 0.78, 0.3))


func _show_announcement(message: String, duration: float, color: Color) -> void:
	if _announcement_tween and _announcement_tween.is_valid():
		_announcement_tween.kill()
	boss_warning.text = message
	boss_warning.add_theme_color_override("font_color", color)
	boss_warning.modulate = Color(color.r, color.g, color.b, 0.0)
	boss_warning.show()
	_announcement_tween = create_tween()
	_announcement_tween.tween_property(boss_warning, "modulate:a", 1.0, 0.25)
	_announcement_tween.tween_interval(maxf(duration - 0.75, 0.0))
	_announcement_tween.tween_property(boss_warning, "modulate:a", 0.0, 0.5)
	_announcement_tween.tween_callback(boss_warning.hide)


# ------------------------------------------------------------------ jogador

func update_hp(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current


func update_xp(current: float, target: float) -> void:
	xp_bar.max_value = target
	xp_bar.value = current


func update_level(level: int) -> void:
	level_label.text = "Lv: %d" % level


func update_time(time_str: String) -> void:
	time_label.text = time_str


func add_kill() -> void:
	_kills += 1
	kills_label.text = "Kills: %d" % _kills


func update_coins(amount: int) -> void:
	coins_label.text = "Moedas: %d" % amount


func add_weapon_icon(
	weapon_id: StringName,
	icon_texture: Texture2D = null,
	display_name: String = ""
) -> void:
	# Evita duplicatas se já tiver equipado
	for child in weapons_container.get_children():
		if child.name == weapon_id:
			if not display_name.is_empty():
				child.tooltip_text = display_name
			return

	var icon: Control
	if icon_texture:
		var texture_rect := TextureRect.new()
		texture_rect.texture = icon_texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon = texture_rect
	else:
		var placeholder := ColorRect.new()
		placeholder.color = _get_placeholder_color(weapon_id)
		icon = placeholder
	icon.name = weapon_id
	icon.custom_minimum_size = Vector2(40, 40)
	icon.tooltip_text = display_name
	weapons_container.add_child(icon)


func clear_inventory_icons() -> void:
	for child in weapons_container.get_children():
		child.free()


func _get_placeholder_color(item_id: StringName) -> Color:
	var id_text := str(item_id)
	if "mjolnir" in id_text:
		return Color.CYAN
	if "aura" in id_text:
		return Color.YELLOW
	if "excalibur" in id_text:
		return Color.WHITE
	if "solar" in id_text:
		return Color.ORANGE
	if "poseidon" in id_text:
		return Color.DODGER_BLUE
	if "medusa" in id_text:
		return Color.MEDIUM_SEA_GREEN
	if "zeus" in id_text:
		return Color.GOLD
	return Color.GRAY
