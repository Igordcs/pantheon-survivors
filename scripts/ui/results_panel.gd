extends Control
## ResultsPanel — Tela mostrada no Game Over (Vitória ou Derrota).

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var time_label: Label = $Panel/VBoxContainer/StatsGrid/TimeValue
@onready var coins_label: Label = $Panel/VBoxContainer/StatsGrid/CoinsValue
@onready var kills_label: Label = $Panel/VBoxContainer/StatsGrid/KillsValue
@onready var bosses_label: Label = $Panel/VBoxContainer/StatsGrid/BossesValue

@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_button.pressed.connect(_on_restart_pressed)


func show_results(is_victory: bool, stats: Dictionary, time_str: String, kills: int) -> void:
	if is_victory:
		title_label.text = "VICTORY!"
		title_label.modulate = Color(1, 0.8, 0.2) # Gold
	else:
		title_label.text = "DEFEAT"
		title_label.modulate = Color(0.8, 0.2, 0.2) # Red
		
	time_label.text = time_str
	coins_label.text = str(stats.get("coins_collected", 0))
	kills_label.text = str(kills)
	bosses_label.text = str(stats.get("bosses_defeated", 0))
	
	show()


func _on_restart_pressed() -> void:
	MusicManager.play_menu_music()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
