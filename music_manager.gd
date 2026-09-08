extends Node

# Pré-carrega as faixas
const MENU_THEME = preload("res://assets/audio/music/Strength%20of%20the%20Titans.mp3")
const GAME_AMBIENCE = preload("res://assets/audio/music/The%20Ice%20Giants.mp3")
const BOSS_THEME = preload("res://assets/audio/music/Aggressor.mp3") # use o nome exato do arquivo

const SFX_LEVEL_UP = preload("res://assets/audio/sfx/levelUp.wav") # confirme se o arquivo está na pasta sfx

var player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	player = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx_player)
	
	play_menu_music()

func play_menu_music() -> void:
	play_music(MENU_THEME, -10.0)

func play_game_music() -> void:
	play_music(GAME_AMBIENCE, -12.0)

func play_boss_music() -> void:
	play_music(BOSS_THEME, -8.0) # volume um pouco mais presente para o combate

func play_level_up_sfx() -> void:
	if sfx_player:
		sfx_player.stream = SFX_LEVEL_UP
		sfx_player.volume_db = -6.0 # volume nítido por cima da música
		sfx_player.play()
		
func play_music(stream: AudioStream, volume_db: float = -10.0) -> void:
	if player == null:
		return
	if player.stream == stream and player.playing:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.play()

func stop_music() -> void:
	if player:
		player.stop()
