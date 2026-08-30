extends Control
## HUD — Mostra as informações do player e da run na tela.

@onready var hp_bar: ProgressBar = $VBoxContainer/TopBar/HPBar
@onready var xp_bar: ProgressBar = $VBoxContainer/TopBar/XPBar
@onready var level_label: Label = $VBoxContainer/TopBar/LevelLabel

@onready var time_label: Label = $VBoxContainer/TopBar/TimeLabel
@onready var kills_label: Label = $VBoxContainer/TopBar/KillsLabel

@onready var weapons_container: HBoxContainer = $VBoxContainer/BottomBar/WeaponsContainer
@onready var boss_bar: ProgressBar = $VBoxContainer/TopBar/BossBar
@onready var boss_warning: Label = $BossWarning

var _kills: int = 0
var _announcement_tween: Tween


func _ready() -> void:
	boss_bar.hide()


func show_boss_bar(maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = maximum
	boss_bar.show()


func show_boss_warning(boss_name: String, duration: float) -> void:
	_show_announcement("%s APPROACHES" % boss_name.to_upper(), duration, Color(1.0, 0.35, 0.2))


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


func update_boss_hp(current: float, _maximum: float = 0.0) -> void:
	boss_bar.value = current


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


func add_weapon_icon(weapon_id: String) -> void:
	# Evita duplicatas se já tiver equipado
	for child in weapons_container.get_children():
		if child.name == weapon_id:
			return
			
	var icon = ColorRect.new()
	icon.name = weapon_id
	icon.custom_minimum_size = Vector2(32, 32)
	# Cores baseadas no id para diferenciar no placeholder
	if "mjolnir" in weapon_id: icon.color = Color.CYAN
	elif "aura" in weapon_id: icon.color = Color.YELLOW
	elif "excalibur" in weapon_id: icon.color = Color.WHITE
	elif "solar" in weapon_id: icon.color = Color.ORANGE
	elif "poseidon" in weapon_id: icon.color = Color.DODGER_BLUE
	elif "medusa" in weapon_id: icon.color = Color.MEDIUM_SEA_GREEN
	elif "zeus" in weapon_id: icon.color = Color.GOLD
	else: icon.color = Color.GRAY
	
	weapons_container.add_child(icon)
