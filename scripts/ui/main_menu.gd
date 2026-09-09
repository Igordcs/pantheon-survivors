extends Control

@onready var play_button: Button = $BottomButtons/PlayButton
@onready var settings_button: Button = $BottomButtons/SettingsButton
@onready var quit_button: Button = $BottomButtons/QuitButton

@onready var settings_modal: Panel = $SettingsModal
@onready var master_slider: HSlider = $SettingsModal/VBoxContainer/MasterVolBox/MasterSlider
@onready var music_slider: HSlider = $SettingsModal/VBoxContainer/MusicVolBox/MusicSlider
@onready var fullscreen_check: CheckBox = $SettingsModal/VBoxContainer/FullscreenCheck
@onready var close_settings_button: Button = $SettingsModal/VBoxContainer/CloseSettingsButton

@onready var title_label: Label = $TopTitleContainer/TitleLabel

func _ready() -> void:
	MusicManager.play_menu_music()
	
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	close_settings_button.pressed.connect(_on_close_settings_pressed)
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	_init_audio_settings()
	_animate_title_pulse()

func _animate_title_pulse() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(title_label, "modulate", Color(1.15, 1.05, 0.75), 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "modulate", Color(0.95, 0.8, 0.35), 1.6).set_trans(Tween.TRANS_SINE)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_selection.tscn")

func _on_settings_pressed() -> void:
	settings_modal.show()
	close_settings_button.grab_focus()

func _on_close_settings_pressed() -> void:
	settings_modal.hide()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _init_audio_settings() -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx != -1:
		master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus_idx))
	var is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.button_pressed = is_fullscreen

func _on_master_slider_changed(value: float) -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx != -1:
		AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))
		AudioServer.set_bus_mute(master_bus_idx, value <= 0.01)

func _on_music_slider_changed(value: float) -> void:
	if MusicManager and MusicManager.player:
		MusicManager.player.volume_db = linear_to_db(value) - 4.0

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
