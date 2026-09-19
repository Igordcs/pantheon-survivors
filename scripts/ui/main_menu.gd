extends Control

const STORY_INTRO_SCENE := "res://scenes/ui/story_intro.tscn"
const PHASE_SELECTION_SCENE := "res://scenes/ui/phase_selection.tscn"

@onready var play_button: Button = $BottomButtons/PlayButton
@onready var shop_button: Button = $BottomButtons/ShopButton
@onready var settings_button: Button = $BottomButtons/SettingsButton
@onready var credits_button: Button = $BottomButtons/CreditsButton
@onready var quit_button: Button = $BottomButtons/QuitButton

@onready var settings_modal: Panel = $SettingsModal
@onready var master_slider: HSlider = $SettingsModal/VBoxContainer/MasterVolBox/MasterSlider
@onready var music_slider: HSlider = $SettingsModal/VBoxContainer/MusicVolBox/MusicSlider
@onready var fullscreen_check: CheckBox = $SettingsModal/VBoxContainer/FullscreenCheck
@onready var close_settings_button: Button = $SettingsModal/VBoxContainer/CloseSettingsButton

@onready var credits_modal: Panel = $CreditsModal
@onready var close_credits_button: Button = $CreditsModal/VBoxContainer/CloseCreditsButton

@onready var title_label: Label = $TopTitleContainer/TitleLabel


func _ready() -> void:
	Global.sandbox_mode = false
	MusicManager.play_menu_music()
	
	play_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_play_pressed()
	)
	shop_button.pressed.connect(func():
		MusicManager.play_ui_click()
		get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")
	)
	settings_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_settings_pressed()
	)
	credits_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_credits_pressed()
	)
	quit_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_quit_pressed()
	)
	
	# Fechar modais
	close_settings_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_close_settings_pressed()
	)
	close_credits_button.pressed.connect(func():
		MusicManager.play_ui_click()
		_on_close_credits_pressed()
	)
	
	# Tela Cheia
	fullscreen_check.toggled.connect(func(toggled_on: bool):
		MusicManager.play_ui_click()
		_on_fullscreen_toggled(toggled_on)
	)
	
	# Sliders de Volume
	master_slider.drag_ended.connect(func(_value_changed: bool):
		MusicManager.play_ui_click()
	)
	music_slider.drag_ended.connect(func(_value_changed: bool):
		MusicManager.play_ui_click()
	)
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	
	_init_audio_settings()
	_animate_title_pulse()


func _animate_title_pulse() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(title_label, "modulate", Color(1.15, 1.05, 0.75), 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "modulate", Color(0.95, 0.8, 0.35), 1.6).set_trans(Tween.TRANS_SINE)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(_resolve_play_scene())


func _resolve_play_scene() -> String:
	return STORY_INTRO_SCENE


func _on_settings_pressed() -> void:
	credits_modal.hide()
	settings_modal.show()
	close_settings_button.grab_focus()


func _on_close_settings_pressed() -> void:
	settings_modal.hide()


func _on_credits_pressed() -> void:
	settings_modal.hide()
	credits_modal.show()
	close_credits_button.grab_focus()


func _on_close_credits_pressed() -> void:
	credits_modal.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _init_audio_settings() -> void:
	master_slider.set_value_no_signal(SaveManager.get_master_volume())
	music_slider.set_value_no_signal(SaveManager.get_music_volume())
	fullscreen_check.set_pressed_no_signal(SaveManager.is_fullscreen_enabled())


func _on_master_slider_changed(value: float) -> void:
	SaveManager.set_master_volume(value)


func _on_music_slider_changed(value: float) -> void:
	SaveManager.set_music_volume(value)


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	SaveManager.set_fullscreen_enabled(toggled_on)