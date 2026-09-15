extends Control
## ResultsPanel — Tela mostrada no Game Over (Vitória ou Derrota).

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var time_label: Label = $Panel/VBoxContainer/StatsGrid/TimeValue
@onready var coins_label: Label = $Panel/VBoxContainer/StatsGrid/CoinsValue
@onready var kills_label: Label = $Panel/VBoxContainer/StatsGrid/KillsValue
@onready var bosses_label: Label = $Panel/VBoxContainer/StatsGrid/BossesValue

@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var phase_label: Label = $Panel/VBoxContainer/PhaseLabel


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)


func show_results(is_victory: bool, stats: Dictionary, time_str: String, kills: int) -> void:
	if is_victory:
		title_label.text = "RUPTURA SELADA"
		title_label.modulate = Color(1, 0.8, 0.2) # Gold
	else:
		title_label.text = "DERROTA"
		title_label.modulate = Color(0.8, 0.2, 0.2) # Red
	_update_phase_line(is_victory, stats)
		
	time_label.text = time_str
	coins_label.text = str(stats.get("coins_collected", 0))
	kills_label.text = str(kills)
	bosses_label.text = str(stats.get("bosses_defeated", 0))
	
	show()


## Fecha o ciclo narrativo da fase: qual ruptura caiu e qual foi detectada em seguida.
func _update_phase_line(is_victory: bool, stats: Dictionary) -> void:
	if phase_label == null:
		return
	var phase_name := String(stats.get("phase_name", ""))
	if phase_name.is_empty():
		phase_label.visible = false
		return
	if is_victory:
		var next_name := String(stats.get("next_phase_name", ""))
		phase_label.text = "%s foi selada.
Uma nova Fenda responde ao chamado: %s." % [
			phase_name, next_name,
		] if not next_name.is_empty() else "%s foi selada.
A campanha chegou ao fim." % phase_name
	else:
		var defeated := int(stats.get("bosses_defeated", 0))
		var total := int(stats.get("anchor_count", 0))
		phase_label.text = "%s resiste.
Âncoras derrubadas: %d de %d." % [phase_name, defeated, total]
	phase_label.visible = true


func _on_restart_pressed() -> void:
	MusicManager.play_menu_music()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
